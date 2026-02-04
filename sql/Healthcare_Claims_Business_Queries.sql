/* =========================================================
   US HEALTHCARE CLAIMS ANALYTICS PROJECT
   ---------------------------------------------------------
   Objective:
   Analyze claim denials, revenue impact, and operational
   efficiency using SQL Server.

   ========================================================= */


/* =========================================================
   STEP 1: CLEAN ANALYTIC LAYER 
   ========================================================= */

CREATE OR ALTER VIEW dbo.vw_claims_clean
AS
SELECT
    claim_id,
    member_id,
    provider_id,
    service_category,
    procedure_code,
    diagnosis_code,
    claim_amount,
    allowed_amount,
    claim_status,
    denial_reason_code,
    region,
    state,
    service_date,
    submission_date,
    adjudication_date,
    Errors,
    Amount_Credibility,
    Processing_Days,
    Claim_Outcome,
    High_Value_Claim_Flag,

    /* Cleaned numeric version for analysis */
    TRY_CAST(
        REPLACE(REPLACE(claim_amount, '$', ''), ',', '')
        AS DECIMAL(10,2)
    ) AS claim_amount_num

FROM dbo.claims_data;
GO


/* =========================================================
   Q1. Join claims with denial reasons
   Business Question:
   How can we map denial codes to human-readable reasons?
   ========================================================= */

SELECT
    c.claim_id,
    c.claim_status,
    c.denial_reason_code,
    d.Reason_for_denial
FROM dbo.vw_claims_clean c
LEFT JOIN dbo.denial_reasons d
    ON c.denial_reason_code = d.Denial_codes;


/* =========================================================
   Q2. Only DENIED claims with reasons
   Business Question:
   Which claims were denied and why?
   ========================================================= */

SELECT
    c.claim_id,
    c.denial_reason_code,
    d.Reason_for_denial,
    c.claim_amount_num,
    c.service_date
FROM dbo.vw_claims_clean c
INNER JOIN dbo.denial_reasons d
    ON c.denial_reason_code = d.Denial_codes
WHERE c.claim_status = 'Denied';


/* =========================================================
   Q3. Denial count by reason
   Business Question:
   What are the most frequent denial reasons?
   ========================================================= */

SELECT
    d.Reason_for_denial,
    COUNT(*) AS denial_count
FROM dbo.vw_claims_clean c
INNER JOIN dbo.denial_reasons d
    ON c.denial_reason_code = d.Denial_codes
WHERE c.claim_status = 'Denied'
GROUP BY d.Reason_for_denial
ORDER BY denial_count DESC;


/* =========================================================
   Q4. Denial percentage by reason
   Business Question:
   What percentage of denials does each reason contribute?
   ========================================================= */

SELECT
    d.Reason_for_denial,
    COUNT(*) * 100.0 /
        (
            SELECT COUNT(*)
            FROM dbo.vw_claims_clean
            WHERE claim_status = 'Denied'
        ) AS denial_percentage
FROM dbo.vw_claims_clean c
INNER JOIN dbo.denial_reasons d
    ON c.denial_reason_code = d.Denial_codes
WHERE c.claim_status = 'Denied'
GROUP BY d.Reason_for_denial
ORDER BY denial_percentage DESC;


/* =========================================================
   Q5. Region-wise denial rate
   Business Question:
   Which regions have the highest denial rates?
   ========================================================= */

SELECT
    region,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS denial_rate_pct
FROM dbo.vw_claims_clean
GROUP BY region
ORDER BY denial_rate_pct DESC;


/* =========================================================
   Q6. Denial rate by High Value Claim Flag
   Business Question:
   Are high-value claims more likely to be denied?
   ========================================================= */

SELECT
    High_Value_Claim_Flag,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS denial_rate_pct
FROM dbo.vw_claims_clean
GROUP BY High_Value_Claim_Flag;


/* =========================================================
   Q7. State-wise denied claim count
   Business Question:
   Which states have the highest number of denied claims?
   ========================================================= */

SELECT
    state,
    COUNT(*) AS denied_claims
FROM dbo.vw_claims_clean
WHERE claim_status = 'Denied'
GROUP BY state
ORDER BY denied_claims DESC;


/* =========================================================
   Q8. Total revenue blocked due to denials
   Business Question:
   How much revenue is currently blocked due to denied claims?
   ========================================================= */

SELECT
    SUM(claim_amount_num) AS total_denied_value
FROM dbo.vw_claims_clean
WHERE claim_status = 'Denied';


/* =========================================================
   Q9. Denied revenue by reason
   Business Question:
   Which denial reasons cause the highest revenue loss?
   ========================================================= */

SELECT
    d.Reason_for_denial,
    SUM(c.claim_amount_num) AS denied_value
FROM dbo.vw_claims_clean c
INNER JOIN dbo.denial_reasons d
    ON c.denial_reason_code = d.Denial_codes
WHERE c.claim_status = 'Denied'
GROUP BY d.Reason_for_denial
ORDER BY denied_value DESC;


/* =========================================================
   Q10. Denied revenue by state
   Business Question:
   Which states contribute most to denied revenue?
   ========================================================= */

SELECT
    state,
    SUM(claim_amount_num) AS denied_value
FROM dbo.vw_claims_clean
WHERE claim_status = 'Denied'
GROUP BY state
ORDER BY denied_value DESC;


/* =========================================================
   Q11. State ranking by denied revenue
   Business Question:
   Rank states based on denied revenue impact.
   ========================================================= */

SELECT
    state,
    SUM(claim_amount_num) AS denied_value,
    RANK() OVER (ORDER BY SUM(claim_amount_num) DESC) AS state_rank
FROM dbo.vw_claims_clean
WHERE claim_status = 'Denied'
GROUP BY state;


/* =========================================================
   Q12. Average denied claim value
   Business Question:
   What is the average value of a denied claim?
   ========================================================= */

SELECT
    AVG(claim_amount_num) AS avg_denied_claim_value
FROM dbo.vw_claims_clean
WHERE claim_status = 'Denied';


/* =========================================================
   Q13. Top 10 highest value claims
   Business Question:
   Which claims carry the highest financial risk?
   ========================================================= */

SELECT TOP 10
    claim_id,
    claim_amount_num,
    claim_status,
    High_Value_Claim_Flag
FROM dbo.vw_claims_clean
ORDER BY claim_amount_num DESC;
