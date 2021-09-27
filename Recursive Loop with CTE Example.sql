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

DROP TABLE IF EXISTS #BOM
GO

WITH bomcte AS(
  SELECT b.ParentPN
        ,b.ChildPN
        ,b.Cost
        ,0 AS Level
        ,b.ParentPN AS SourcePN
        ,CAST(b.ParentPN AS NVARCHAR(MAX)) AS DemandBranch
  FROM #Req b
  WHERE b.ParentPN = 'Major SubAssy 1' --set the PN from the PN list that you are making; use Major SubAssy 1

  UNION ALL
  
  SELECT b.ParentPN
        ,b.ChildPN
        ,b.Cost
        ,bc.Level + 1 AS Level
        ,bc.SourcePN
        ,CAST(bc.DemandBranch AS NVARCHAR(MAX)) + ' > ' + CAST(b.ParentPN AS NVARCHAR(MAX)) AS DemandBranch
  FROM #Req b
  INNER JOIN bomcte bc
    ON bc.ChildPN = b.ParentPN
  )
--Store CTE into temp table
SELECT *
  INTO #BOM
  FROM bomcte
 
----------------------------------
--USE RECURSIVE LOOP TO ITERATE THROUGH PARENT/CHILD RELATIONSHIP

SELECT *
  FROM #BOM b
  