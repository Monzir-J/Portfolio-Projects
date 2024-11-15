--SELECT the database we're going to use
USE DataExplorationProject

-- **Understanding the Structure of Our CovidDeaths Data**
-- This query inspects the columns of the 'CovidDeaths' table to gain insights into their data types, lengths, and nullability.
-- This information is crucial for subsequent data cleaning, analysis, and visualization.

SELECT 
    COLUMN_NAME AS Column_Name,  -- Aliasing for better readability
    DATA_TYPE AS Data_Type,
    CHARACTER_MAXIMUM_LENGTH AS Max_Length,
    NUMERIC_PRECISION AS Numeric_Precision,
    NUMERIC_SCALE AS Numeric_Scale,
    IS_NULLABLE AS Is_Nullable
FROM 
    INFORMATION_SCHEMA.COLUMNS
WHERE 
    TABLE_NAME = 'CovidDeaths';

-- **Understanding the Structure of Our CovidVaccinations Data**
-- This query examines the columns of the 'CovidVaccinations' table to gain insights into their data types, lengths, and nullability.
-- This information is crucial for subsequent data cleaning, analysis, and visualization, particularly when merging with the 'CovidDeaths' table.

SELECT 
    COLUMN_NAME AS Column_Name,  -- Aliasing for better readability
    DATA_TYPE AS Data_Type,
    CHARACTER_MAXIMUM_LENGTH AS Max_Length,
    NUMERIC_PRECISION AS Numeric_Precision,
    NUMERIC_SCALE AS Numeric_Scale,
    IS_NULLABLE AS Is_Nullable
FROM 
    INFORMATION_SCHEMA.COLUMNS
WHERE 
    TABLE_NAME = 'CovidVaccinations';

--Select data that we are going to be using
SELECT	location,date,total_cases,new_cases,total_deaths,population
FROM CovidDeaths
where continent is NOT NULL
ORDER BY 1,2

-- **Calculating Death Percentage by Location and Date**
-- This query calculates the percentage of deaths relative to total cases for each location and date, providing insights into the severity of the pandemic.

SELECT 
    location, 
    date, 
    total_cases, 
    total_deaths, 
    ROUND((total_deaths / total_cases) * 100, 2) AS DeathPercentage
FROM 
    DataExplorationProject..CovidDeaths
WHERE 
    continent IS NOT NULL
ORDER BY 
    1, 2;
-- **Calculating Population Infection Percentage**
-- This query calculates the percentage of the population infected with COVID-19 for each location and date, providing insights into the extent of the outbreak.

SELECT 
    location, 
    date, 
    Population, 
    total_cases, 
    ROUND((total_cases / Population) * 100, 7) AS PopulationInfectionPercentage
FROM 
    DataExplorationProject..CovidDeaths
WHERE 
    continent IS NOT NULL
ORDER BY 
    1, 2;

-- **Finding Countries with Highest Infection Rates**
-- This query identifies countries with the highest infection rates compared to their population.

SELECT 
    location, 
    Population, 
    MAX(total_cases) AS TotalCases, 
    MAX((total_cases / Population)) * 100 AS PopulationInfectionPercentage
FROM 
    DataExplorationProject..CovidDeaths
WHERE 
    continent IS NOT NULL
GROUP BY 
    location, Population
ORDER BY 
    PopulationInfectionPercentage DESC;

-- **Finding Locations with Highest Death Rates**
-- This query identifies locations (likely countries) with the highest death rates compared to their population.

SELECT 
    location, 
    Population, 
    MAX(CAST(total_deaths AS INT)) AS Total_Deaths, 
    MAX((CAST(total_deaths AS INT) / Population)) * 100 AS DeathPercentage
FROM 
    DataExplorationProject..CovidDeaths
WHERE 
    continent IS NULL
GROUP BY 
    location, Population
ORDER BY 
    DeathPercentage DESC;

-- **Highest Cases by Location**
-- This query identifies the highest number of total cases for each continent.

SELECT 
    location, 
    MAX(CAST(total_cases AS INT)) AS HighestCases
FROM 
    DataExplorationProject..CovidDeaths
WHERE 
    continent IS NULL
GROUP BY 
    location
ORDER BY 
    HighestCases DESC

-- **Global COVID-19 Statistics**
-- This query calculates the total number of cases, total number of deaths, and the overall death percentage globally.

SELECT 
    SUM(new_cases) AS TotalCases,
    SUM(CAST(new_deaths AS INT)) AS TotalDeaths,
    SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100 AS DeathPercentage
FROM 
    DataExplorationProject..CovidDeaths
WHERE 
    continent IS NOT NULL;
-- **Top 10 Infected Countries**
-- This query identifies the top 10 countries with the highest total number of cases.

SELECT TOP 10
    location,
    SUM(new_cases) AS Total_Cases,
    RANK() OVER (ORDER BY SUM(new_cases) DESC) AS Rank
FROM 
    DataExplorationProject..CovidDeaths
WHERE 
    continent IS NOT NULL
GROUP BY 
    location
ORDER BY 
    Rank;
-- **Calculating Rolling Population Vaccination**
-- This query joins the 'CovidDeaths' and 'CovidVaccinations' tables to calculate the cumulative 
-- number of vaccinations for each location over time.

SELECT 
    Deaths.continent,
    Deaths.location,
    Deaths.date,
    Deaths.population,
    VAC.new_vaccinations,
    SUM(CAST(VAC.new_vaccinations AS INT)) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location, Deaths.date) AS RollingPopulationVaccination
FROM 
    DataExplorationProject..CovidDeaths AS Deaths
INNER JOIN 
    DataExplorationProject..CovidVaccinations AS VAC
ON 
    Deaths.location = VAC.location
    AND Deaths.date = VAC.date
WHERE 
    Deaths.continent IS NOT NULL
ORDER BY 
    2, 3;  -- Order by location and date

-- **Calculating Rolling Population Vaccination**
-- This CTE calculates the cumulative number of vaccinations for each location over time, taking into account potential missing values and data inconsistencies.
WITH PopVsVac AS (
    SELECT 
        Deaths.continent,
        Deaths.location,
        Deaths.date,
        Deaths.population,
        COALESCE(VAC.new_vaccinations, 0) AS new_vaccinations,  -- Handle missing values
        SUM(COALESCE(VAC.new_vaccinations, 0)) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location, Deaths.date) AS RollingPopulationVaccination
    FROM 
        DataExplorationProject..CovidDeaths AS Deaths
    INNER JOIN 
        DataExplorationProject..CovidVaccinations AS VAC
    ON 
        Deaths.location = VAC.location
        AND Deaths.date = VAC.date
    WHERE 
        Deaths.continent IS NOT NULL
        AND VAC.new_vaccinations > 0  -- Filter out rows with zero vaccinations
)
SELECT *,
       (RollingPopulationVaccination / population) * 100 AS VaccinationPercentage
FROM PopVsVac;

--TEMP TABLE
DROP TABLE IF Exists #percentPopulationVaccinated
CREATE TABLE #percentPopulationVaccinated
(
Continent nvarchar(255),
Location  nvarchar(255),
Date	  datetime,
Population numeric,
New_vaccinations numeric,
RollingPopulationVaccination numeric
)
INSERT INTO #percentPopulationVaccinated
SELECT 
	Deaths.continent,Deaths.location,Deaths.date,Deaths.population,VAC.new_vaccinations
	,SUM(CAST(VAC.new_vaccinations as INT)) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location,Deaths.date) as RollingPopulationVaccination
FROM DataExplorationProject..CovidDeaths AS Deaths
JOIN DataExplorationProject..CovidVaccinations AS VAC
ON Deaths.[location] = VAC.location
	AND Deaths.date = VAC.date
	where Deaths.continent IS NOT NULL
SELECT *,(RollingPopulationVaccination/population)*100
FROM #percentPopulationVaccinated



		




