
/*## Lahman Baseball Database Exercise
- this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
- you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)*/

-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?

SELECT sc.schoolid, sc.schoolname, p.playerid, p.namefirst, p.namelast, SUM(sa.salary) AS salary
FROM people AS p
INNER JOIN collegeplaying AS c
USING(playerid)
INNER JOIN schools AS sc
USING(schoolid)
INNER JOIN salaries AS sa
USING(playerid)
WHERE LOWER(schoolname) LIKE  '%vand%'
GROUP BY p.playerid, sc.schoolname, sc.schoolid, p.namefirst, p.namelast
ORDER BY sc.schoolname, salary DESC
LIMIT 1;
-- David Price earned $245553888 in the majors

-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

SELECT *
FROM fielding;

SELECT 
    yearid,
    CASE WHEN LOWER(pos) IN ('ss', '1b', '2b', '3b') THEN 'infield'
        WHEN LOWER(pos) = 'of' THEN 'outfield'
        WHEN LOWER(pos) IN ('p', 'c') THEN 'battery' ELSE NULL END AS position_group, 
        SUM(po) AS putouts
FROM fielding
WHERE yearid = 2016
GROUP BY yearid, position_group;



-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)


SELECT *
FROM teams;

-- avg strikeouts per game by decade since 1920
SELECT 
    trunc(yearid, -1)||'s' AS decade,
    AVG(g) AS avg_games_played,
    AVG(so) AS avg_strikeouts_pitching,
    ROUND(SUM(so)::NUMERIC / (SUM(g)::NUMERIC), 2) AS avg_so_per_game
FROM teams
WHERE yearid >= 1920
GROUP BY decade
ORDER BY decade;

-- avg hr per game by decade since 1920
SELECT 
    trunc(yearid, -1) ||'s' AS decade,
    AVG(g) AS avg_games_played,
    AVG(hr) AS avg_hr_per_year,
    ROUND(SUM(hr)::NUMERIC / (SUM(g)::NUMERIC), 2) AS avg_hr_per_game
FROM teams
WHERE yearid >= 1920
GROUP BY decade
ORDER BY decade;



-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.

-- name, sb, att, sb_pct 

SELECT 
    namefirst || ' ' || namelast AS name, 
    sb, 
    cs,
    sb + cs AS att,
    ROUND((sb::NUMERIC / (sb::NUMERIC + cs::NUMERIC)) * 100, 2) AS sb_pct
FROM batting AS b
INNER JOIN people AS p
USING (playerid)
WHERE yearid = 2016 AND sb + cs >=20
GROUP BY name, sb, cs
ORDER BY sb_pct DESC
LIMIT 1;





-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

-- most wins, no world series
SELECT yearid, name, w, l, wswin 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
    AND wswin = 'N'
ORDER BY w DESC
LIMIT 1;
-- 2001 Mariners: 116 W 


 -- least wins, world series
SELECT yearid, name, w, l, wswin 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
    AND wswin = 'Y'
ORDER BY w;
-- 1981 Dodgers: 63 W


-- 1981 players strike, exclude 1981
SELECT yearid, name, w, l, wswin 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
    AND wswin = 'Y'
    AND yearid <> 1981
ORDER BY w
LIMIT 1;
-- 2006 Cards: 83 W


-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.


-- tables to join: 
-- teams, managers, people, awardsmanagers 

SELECT 
    playerid, 
    namefirst || ' ' || namelast AS name, 
    am.yearid, 
    awardid, 
    am.lgid, 
    t.name AS teamname
FROM awardsmanagers AS am
LEFT JOIN people AS p
USING (playerid)
LEFT JOIN managers AS m
USING (playerid, yearid)
LEFT JOIN teams as t
USING (teamid, yearid)
WHERE
    am.lgid <> 'ML'
    AND awardid = 'TSN Manager of the Year'
    AND playerid IN (
        SELECT playerid
        FROM awardsmanagers 
        WHERE 
            awardid = 'TSN Manager of the Year'
            AND lgid <> 'ML'
        GROUP BY playerid
        HAVING COUNT(DISTINCT lgid) = 2
);

-- more efficient way i think 
WITH multi_league_winners AS (
    SELECT playerid
    FROM awardsmanagers
    WHERE awardid = 'TSN Manager of the Year'
      AND lgid IN ('AL', 'NL')
    GROUP BY playerid
    HAVING COUNT(DISTINCT lgid) = 2
) -- prefiltering out minor leagues and other awards

SELECT 
    am.playerid, 
    p.namefirst || ' ' || p.namelast AS name, 
    am.yearid, 
    am.awardid, 
    am.lgid, 
    t.name AS teamname
FROM awardsmanagers AS am
INNER JOIN multi_league_winners mlw
USING(playerid)
LEFT JOIN people AS p
USING(playerid)
LEFT JOIN managers AS m
USING (playerid, yearid)
LEFT JOIN teams AS t
USING (teamid, yearid)
WHERE am.awardid = 'TSN Manager of the Year'
  AND am.lgid IN ('AL', 'NL');



-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.

SELECT 
    namefirst ||' ' || namelast AS name, 
    SUM(salary) AS salary,
    SUM(so) AS strikeouts,
    SUM(gs) AS games_started,
    ROUND((SUM(so::NUMERIC) / SUM(salary::NUMERIC)), 10) AS so_per_$
FROM salaries AS s
INNER JOIN pitching AS pt
    USING(playerid)
INNER JOIN people as p
    USING(playerid)
WHERE s.yearid = 2016 
    AND gs >= 10
GROUP BY    
   name 
ORDER BY 
    so_per_$
LIMIT 1;
-- Zack Greinke was the least efficient at 0.0000048768 strikeouts per dollar 







-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.

-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

-- 12. In this question, you will explore the connection between number of wins and attendance.

    -- a. Does there appear to be any correlation between attendance at home games and number of wins?  
    -- b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?
