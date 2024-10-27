SELECT *
FROM DataExplorationProject..covidDeaths
where continent is   NULL
ORDER BY 3,4




--SELECT *
--FROM DataExplorationProject..Covidvaccinations
--ORDER BY 3,4

--Select data that we are going to be using

SELECT	location,date,total_cases,new_cases,total_deaths,population
FROM DataExplorationProject..CovidDeaths
where continent is NOT NULL
ORDER BY 1,2


--Total Cases VS Total Deaths
SELECT	location,date,total_cases,total_deaths ,ROUND((total_deaths/total_cases)*100,2) as DeathPrecentage
FROM DataExplorationProject..CovidDeaths
WHERE location = 'Africa' AND
continent is NOT NULL
ORDER BY 1,2

-- Total Cases VS Population
SELECT	location,date,Population ,total_cases,(total_cases/population)*100 as PopulationInfectionPrecentage
FROM DataExplorationProject..CovidDeaths
where continent is NOT NULL AND
location  like '%united%'
ORDER BY 1,2

--Looking for countries with highes infection rate compared to population
SELECT	location,Population ,MAX(total_cases) total_cases,MAX((total_cases/population))*100 as PopulationInfectionPrecentage
FROM DataExplorationProject..CovidDeaths
where continent is NOT NULL
GROUP BY location,Population 
ORDER BY PopulationInfectionPrecentage DESC

--Deaths per population

SELECT	location,Population ,MAX(CAST(total_deaths as int)) as Total_deaths,MAX((CAST(total_deaths as INT)/population))*100 as DeathsPrecenatge
FROM DataExplorationProject..CovidDeaths
WHERE continent is  NULL
GROUP BY location,Population 
ORDER BY DeathsPrecenatge DESC

--BREAKES'S THINGS BY CONTITNET

SELECT 
	location,MAX(cast(total_cases as int)) HighestCases
FROM DataExplorationProject..covidDeaths
where continent is   NULL
GROUP BY location
Order by HighestCases desc

--GLOBAL NUMBERS
SELECT 
	SUM(new_cases) totalCases
	,SUM(CAST(new_deaths as INT)) as TotalDeaths
	,SUM(CAST(new_deaths as INT)) / SUM(new_cases)*100 as DeathPrecentage
FROM DataExplorationProject..covidDeaths
where continent is NOT NULL
ORDER BY 1,2

--TOP 10 infected countries
SELECT
	TOP 10 (location)
	,SUM(new_cases) AS Total_cases
	,RANK() OVER (ORDER BY  SUM(new_cases) DESC) Rank
FROM DataExplorationProject..covidDeaths
WHERE continent IS NOT NULL
GROUP BY location
HAVING SUM(new_cases)   IS NOT NULL


-- Total Population VS Vaccination
SELECT 
	Deaths.continent,Deaths.location,Deaths.date,Deaths.population,VAC.new_vaccinations
	,SUM(CAST(VAC.new_vaccinations as INT)) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location,Deaths.date) as RollingPopulationVaccination
FROM DataExplorationProject..CovidDeaths AS Deaths
JOIN DataExplorationProject..CovidVaccinations AS VAC
ON Deaths.[location] = VAC.location
	AND Deaths.date = VAC.date
	where Deaths.continent IS NOT NULL
ORDER BY 2,3;

--Using CTE
WITH PopVsVac
AS (SELECT 
	Deaths.continent,Deaths.location,Deaths.date,Deaths.population,VAC.new_vaccinations
	,SUM(CAST(VAC.new_vaccinations as INT)) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location,Deaths.date) as RollingPopulationVaccination
FROM DataExplorationProject..CovidDeaths AS Deaths
JOIN DataExplorationProject..CovidVaccinations AS VAC
ON Deaths.[location] = VAC.location
	AND Deaths.date = VAC.date
	where Deaths.continent IS NOT NULL
	)
SELECT *,(RollingPopulationVaccination/population)*100
FROM PopVsVac

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



		




