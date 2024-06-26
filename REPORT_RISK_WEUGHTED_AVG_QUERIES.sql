
WITH CTE AS(
SELECT REPORT_ID,
CASE WHEN TRANSACTION_RISK+ENTITY_RISK+GOS_RISK = 0 THEN 0
ELSE
((SQUARE(TRANSACTION_RISK)+SQUARE(ENTITY_RISK)+SQUARE(GOS_RISK))/(TRANSACTION_RISK+ENTITY_RISK+GOS_RISK)) END AS RISK_SCORE_WEIGHTAGE

FROM (
SELECT REPORT_ID,AVG(TRANSACTION_RISK) AS TRANSACTION_RISK,
AVG(ENTITY_RISK) AS ENTITY_RISK,
AVG(GOS_RISK) AS GOS_RISK
FROM (
SELECT DISTINCT RTSS.REPORT_ID,
COALESCE(RT.RISK_SCORE,0) AS TRANSACTION_RISK,
ENTITY_ID,ENTITY_TYPE,
COALESCE(RP.RISK_SCORE,RO.RISK_SCORE,0) AS ENTITY_RISK,
COALESCE(RG.RISK_SCORE,0) AS GOS_RISK
FROM FINCORE_DB.Fincore_Analytics.RISK_TRANSACTION_SUMMARY_STG RTSS WITH (NOLOCK)
LEFT JOIN FINCORE_DB.Fincore_Analytics.RISK_TRANSACTION RT WITH (NOLOCK) ON RT.REPORT_ID = RTSS.REPORT_ID
LEFT JOIN FINCORE_DB.Fincore_Analytics.RISK_PERSON RP WITH (NOLOCK) ON RTSS.ENTITY_ID = RP.PERSON_MASTER_ID AND RTSS.ENTITY_TYPE = 'I' 
LEFT JOIN FINCORE_DB.Fincore_Analytics.RISK_ORGANIZATION RO WITH (NOLOCK) ON RTSS.ENTITY_ID = RO.ORGANIZATION_MASTER_ID AND RTSS.ENTITY_TYPE = 'O' 
LEFT  JOIN FINCORE_DB.Fincore_Analytics.RISK_GOS RG WITH (NOLOCK) ON RG.REPORT_ID = RTSS.REPORT_ID
)T
GROUP BY REPORT_ID)T
WHERE REPORT_ID NOT IN (
select REPORT_ID from Fincore_Analytics.RISK_REPORT_RULES A
inner join Fincore_Analytics.RISK_LKP_RULES B 
on A.RULE_NO = B.RULE_NO
where B.PERSON_TYPE = 'Report' and B.RISK_TYPE = 'Auto High Rules ')
)
UPDATE FINCORE_DB.Fincore_Analytics.RISK_REPORT
SET RISK_SCORE_WEIGHTED_AVG = CTE.RISK_SCORE_WEIGHTAGE
FROM CTE 
INNER JOIN FINCORE_DB.Fincore_Analytics.RISK_REPORT RR
ON CTE.REPORT_ID = RR.REPORT_ID
WHERE CTE.REPORT_ID NOT IN (
select REPORT_ID from Fincore_Analytics.RISK_REPORT_RULES A
inner join Fincore_Analytics.RISK_LKP_RULES B 
on A.RULE_NO = B.RULE_NO
where B.PERSON_TYPE = 'Report' and B.RISK_TYPE = 'Auto High Rules ')








WITH CTE AS(
SELECT 
REPORT_ID,
CASE WHEN (RISK_SCORE_QUERY+RISK_SCORE_WEIGHTAGE) = 0 THEN 0
ELSE ((SQUARE(RISK_SCORE_QUERY)+SQUARE(RISK_SCORE_WEIGHTAGE))/(RISK_SCORE_QUERY+RISK_SCORE_WEIGHTAGE)) END AS RISK_SCORE
FROM (
SELECT REPORT_ID,
COALESCE(RISK_SCORE_QUERY,0) AS RISK_SCORE_QUERY,
COALESCE(RISK_SCORE_WEIGHTED_AVG,0) AS RISK_SCORE_WEIGHTAGE
FROM FINCORE_DB.Fincore_Analytics.RISK_REPORT RR WITH (NOLOCK)
)T
WHERE T.REPORT_ID NOT IN (
select REPORT_ID from Fincore_Analytics.RISK_REPORT_RULES A
inner join Fincore_Analytics.RISK_LKP_RULES B 
on A.RULE_NO = B.RULE_NO
where B.PERSON_TYPE = 'Report' and B.RISK_TYPE = 'Auto High Rules ')
)
UPDATE FINCORE_DB.Fincore_Analytics.RISK_REPORT
SET RISK_SCORE = CTE.RISK_SCORE
FROM CTE 
INNER JOIN FINCORE_DB.Fincore_Analytics.RISK_REPORT RR
ON CTE.REPORT_ID = RR.REPORT_ID
