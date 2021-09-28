/*
Query will perform BOM rollup on a set of PartNumbers and their Requirements (Parent/Child) relationship.
  Once it creates the BOM, it will rollup the raw material cost into the parent materials.
  Ignore labor.

  */

----------------------------------
--CREATE PARTS LIST WITH PARENT CHILD RELATIONSHIP
DROP TABLE IF EXISTS #Req;
CREATE TABLE #Req (ParentPN NVARCHAR(20), ChildPN NVARCHAR(20), Cost DECIMAL(18,2))

INSERT INTO #Req (ParentPN, ChildPN, Cost)
  VALUES ('Major SubAssy 1','SubAssy 1',0),
('Major SubAssy 1','SubAssy 2',0),
('SubAssy 1','Raw Mat 1',0),
('SubAssy 1','Raw Mat 2',0),
('SubAssy 1','Raw Mat 3',0),
('SubAssy 2','Raw Mat 4',0),
('SubAssy 2','Raw Mat 5',0),
('SubAssy 2','Raw Mat 6',0),
('Raw Mat 1','',10),
('Raw Mat 2','',15),
('Raw Mat 3','',30),
('Raw Mat 4','',8),
('Raw Mat 5','',5),
('Raw Mat 6','',25)

----------------------------------
--USE RECURSIVE LOOP TO ITERATE THROUGH PARENT/CHILD RELATIONSHIP; STORE INTO TABLE
--Use CHECKSUM to create an INTEGERS; joining on INTEGERS is faster than joining on STRING

DROP TABLE IF EXISTS #BOM
GO

WITH bomcte AS(
  SELECT b.ParentPN
        ,b.ChildPN
        ,b.Cost
        ,0 AS Level
        ,b.ParentPN AS SourcePN
        ,CHECKSUM(b.ParentPN) AS SourcePNID
        ,CAST(b.ParentPN AS NVARCHAR(MAX)) AS DemandBranch
        ,CHECKSUM(CAST(b.ParentPN AS NVARCHAR(MAX))) AS DemandBranchID
        ,NULL AS ParentBranchID
  FROM #Req b
  WHERE b.ParentPN = 'Major SubAssy 1' --set the PN from the PN list that you are making; use Major SubAssy 1

  UNION ALL
  
  SELECT b.ParentPN
        ,b.ChildPN
        ,b.Cost
        ,bc.Level + 1 AS Level
        ,bc.SourcePN
        ,bc.SourcePNID
        ,CAST(bc.DemandBranch AS NVARCHAR(MAX)) + ' > ' + CAST(b.ParentPN AS NVARCHAR(MAX)) AS DemandBranch
        ,CHECKSUM(CAST(bc.DemandBranch AS NVARCHAR(MAX)) + ' > ' + CAST(b.ParentPN AS NVARCHAR(MAX))) AS DemandBranchID
        ,bc.DemandBranchID AS ParentBranchID
  FROM #Req b
  INNER JOIN bomcte bc
    ON bc.ChildPN = b.ParentPN
  )
--Store CTE into temp table
SELECT *
  INTO #BOM
  FROM bomcte
 
--  SELECT *
--    FROM #BOM b

----------------------------------
--CONDENSE DATA INTO UNIQUE P/N
DROP TABLE IF EXISTS #BOMFlat;
SELECT b.ParentPN
      ,SUM(b.Cost) AS Cost
      ,b.Level
      ,b.SourcePN
      ,b.SourcePNID
      ,b.DemandBranch
      ,b.DemandBranchID
      ,b.ParentBranchID
  INTO #BOMFlat
  FROM #BOM b
  GROUP BY b.ParentPN      
      ,b.Level
      ,b.SourcePN
      ,b.SourcePNID
      ,b.DemandBranch
      ,b.DemandBranchID
      ,b.ParentBranchID
  ORDER BY b.Level



----------------------------------
--Use While Loop to sum Costs, and store in Rollup temp table
--Using CTE in this step prevents aggregation 
DROP TABLE IF EXISTS #Rollup;
CREATE TABLE #Rollup (DemandBranchID INT, ParentBranchID INT, Level SMALLINT, Cost DECIMAL(18,2), SourcePNID INT)
CREATE NONCLUSTERED INDEX costrollup ON #Rollup(DemandBranchID, ParentBranchID, SourcePNID) --create non-clustered index to speed up JOINs 

DECLARE @MaxL AS INT = (SELECT MAX(b.Level) FROM #BOMFlat b)
DECLARE @Loop AS INT = @MaxL

WHILE @Loop >= 0
  BEGIN
    INSERT INTO #Rollup (DemandBranchID, ParentBranchID, Level, Cost, SourcePNID)

SELECT 
  b.DemandBranchID
  ,b.ParentBranchID
  ,b.Level
  ,SUM(b.Cost+ISNULL(r.Cost,0)) AS CostAgg
  ,b.SourcePNID
  FROM #BOMFlat b
  LEFT JOIN #Rollup r
    ON r.ParentBranchID = b.DemandBranchID
    AND r.SourcePNID = b.SourcePNID --make sure you're looping in the same branch
    AND r.Level = @Loop + 1
  WHERE b.Level = @Loop
  GROUP BY b.DemandBranchID
  ,b.ParentBranchID
  ,b.Level
  ,b.SourcePNID
  
    SET @Loop = @Loop - 1

  END

----------------------------------
--Summarize Cost Data

SELECT *
FROM #Rollup r