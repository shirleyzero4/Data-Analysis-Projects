-- Data Cleaning

SELECT *
FROM layoffs;

-- 1. Remove duplicates
-- 2. Standardize the data
-- 3. Null Values or blank value 
-- 4. Remove any columns

-- Create separate staging data from raw data
CREATE TABLE layoffs_staging
LIKE layoffs;

SELECT *
FROM layoffs_staging;

INSERT layoffs_staging
SELECT *
FROM layoffs;

-- 1. Remove duplicates
-- Look at all rows and row_num++ if a row matches
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, 
percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

-- CTE returning only rows that contain duplicate (row_num > 1), partition over every column
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, 
percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- Verify duplicate
SELECT *
FROM layoffs_staging
WHERE company = 'Casper';

-- Create new duplicate table with new row_nums
CREATE TABLE `layoffs_staging_2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inserted a copy of columns from staging + row_nums 
INSERT INTO layoffs_staging_2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, 
percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

-- Delete duplicates
DELETE 
FROM layoffs_staging_2
WHERE row_num > 1;

-- Verify deleted
SELECT *
FROM layoffs_staging_2
WHERE row_num > 1;

-- 2. Standardize the data

-- Trim company names
SELECT company, (TRIM(company))
FROM layoffs_staging_2;

UPDATE layoffs_staging_2
SET company = TRIM(company);

-- Standardize crypto/cryptocurrency to be one thing
UPDATE layoffs_staging_2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- United States has . at end
SELECT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging_2
WHERE country LIKE 'United States.%'
ORDER By 1;

UPDATE layoffs_staging_2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States.%';

-- Verify change
SELECT distinct(country)
FROM layoffs_staging_2
order by 1;

-- Change date from text to date time
SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging_2;

UPDATE layoffs_staging_2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging_2
MODIFY COLUMN `date` DATE;

-- 3. Null and blank values

-- Populate industry if possible, look at company name
UPDATE layoffs_staging_2
SET industry = null
WHERE industry = '';

SELECT *
FROM layoffs_staging_2
WHERE industry IS NULL
OR industry = '';

SELECT *
FROM layoffs_staging_2
WHERE company = 'Airbnb';

-- Self JOIN and update NULL industry based on company name where industry is filled in
SELECT *
FROM layoffs_staging_2 t1
JOIN layoffs_staging_2 t2
	ON t1.company = t2.company
    AND t1.location = t2.location
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

UPDATE layoffs_staging_2 t1
JOIN layoffs_staging_2 t2
	ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

SELECT *
FROM layoffs_staging_2;

-- 4. Remove row or columns we don't need

-- If both total_laid_off and percentage_laid_off are blank, there isn't much info to look at
SELECT *
FROM layoffs_staging_2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE 
FROM layoffs_staging_2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *
FROM layoffs_staging_2;

-- Remove row_num column, we used it already and don't need it anymore
ALTER TABLE layoffs_staging_2
DROP COLUMN row_num;

-- Done