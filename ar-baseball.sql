/*## Lahman Baseball Database Exercise
- this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
- you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)*/
-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?


WITH vandyboys AS (
    SELECT playerid, schoolid 
    FROM collegeplaying
    WHERE LOWER(schoolid) LIKE '%vand%'
    GROUP BY playerid, schoolid
)
SELECT 
    namefirst||' '||namelast AS playername,
    SUM(salary::NUMERIC::MONEY) AS total_salary
FROM salaries AS s
    INNER JOIN people AS p USING (playerid)
    RIGHT JOIN vandyboys AS v USING (playerid)
GROUP BY playername
ORDER BY total_salary DESC NULLS LAST
LIMIT 1;

-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

SELECT *
FROM fielding;

SELECT
    yearid,
    CASE WHEN LOWER(pos) IN ('ss', '1b', '2b', '3b') THEN 'infield'
    WHEN LOWER(pos) = 'of' THEN 'outfield'
    WHEN LOWER(pos) IN ('p', 'c') THEN 'battery'
    ELSE NULL
    END AS position_group,
    SUM(po) AS putouts
FROM fielding
WHERE yearid = 2016
GROUP BY yearid, position_group;

-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)
SELECT *
FROM teams;

-- avg strikeouts and homeruns per game by decade since 1920
SELECT
    trunc(yearid, -1) || 's' AS decade,
    AVG(g) AS avg_games_played,
    AVG(so) AS avg_strikeouts_pitching,
    ROUND(SUM(so)::numeric /(SUM(g)::numeric), 2) AS avg_so_per_game,
    ROUND(SUM(hr)::numeric /(SUM(g)::numeric), 2) AS avg_hr_per_game
FROM teams
WHERE yearid >= 1920
GROUP BY decade
ORDER BY decade;

-- using generate_series
WITH years AS (
	SELECT generate_series(1920, 2020, 10) AS decades
	)
SELECT decades, ROUND(SUM(so) * 1.0/SUM(g), 2) AS avg_strikeouts_per_game
FROM teams AS t
INNER JOIN years
ON t.yearid < (decades + 10) AND t.yearid >= decades
GROUP BY decades;

WITH years AS (
	SELECT generate_series(1920, 2020, 10) AS decades
	)
SELECT decades, ROUND(SUM(hr) * 1.0/SUM(g), 2) AS avg_homeruns_per_game
FROM teams AS t
INNER JOIN years
ON t.yearid < (decades + 10) AND t.yearid >= decades
GROUP BY decades;


-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.

-- name, sb, att, sb_pct
SELECT
    namefirst || ' ' || namelast AS name,
    SUM(sb),
    SUM(cs),
    SUM(sb + cs) AS att,
    ROUND((SUM(sb)::numeric /(SUM(sb)::numeric + SUM(cs)::numeric)) * 100, 2) AS sb_pct
FROM batting AS b
    INNER JOIN people AS p USING (playerid)
WHERE yearid = 2016
GROUP BY name
HAVING SUM(sb + cs) >= 20
ORDER BY sb_pct DESC;
-- LIMIT 1;

-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; 
    --determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

-- most wins, no world series
-- 2001 Mariners: 116 W
SELECT yearid, name, w, l, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
    AND wswin = 'N'
ORDER BY w DESC
LIMIT 1;

-- 1981 Dodgers: 63 W
-- 1981 players strike, exclude 1981
SELECT yearid, name, w, l, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
    AND wswin = 'Y'
ORDER BY w;

-- least wins, world series
-- 2006 Cards: 83 W
SELECT yearid, name, w, l, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
    AND wswin = 'Y'
    AND yearid <> 1981
ORDER BY w
LIMIT 1;


--How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?
WITH ranked_teams AS (
    SELECT
        yearid,
        name,
        w,
        wswin,
        RANK() OVER (PARTITION BY yearid ORDER BY w DESC) AS rank
    FROM teams
    WHERE yearid BETWEEN 1970 AND 2016
)
SELECT 
    COUNT(*) AS n_most_w_and_wswin,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ranked_teams), 2) AS pct
FROM ranked_teams
WHERE rank = 1
    AND wswin = 'Y';


-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

-- tables to join:
-- teams, managers, people, awardsmanagers
WITH multi_league_winners AS (
    SELECT playerid
    FROM awardsmanagers
    WHERE awardid = 'TSN Manager of the Year'
        AND lgid IN ('AL', 'NL')
    GROUP BY playerid
    HAVING COUNT(DISTINCT lgid) = 2)
SELECT
    am.playerid,
    p.namefirst || ' ' || p.namelast AS name,
    am.yearid,
    am.awardid,
    am.lgid,
    t.name AS teamname
FROM awardsmanagers AS am
    INNER JOIN multi_league_winners mlw USING (playerid)
    LEFT JOIN people AS p USING (playerid)
    LEFT JOIN managers AS m USING (playerid, yearid)
    LEFT JOIN teams AS t USING (teamid, yearid)
WHERE
    am.awardid = 'TSN Manager of the Year'
    AND am.lgid IN ('AL', 'NL');

-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.

-- this is for pitchers who started 10 or more games for one team in 2016
SELECT
    namefirst || ' ' || namelast AS name,
    SUM(salary) AS salary,
    SUM(so) AS strikeouts,
    SUM(gs) AS games_started,
    ROUND((SUM(so::numeric) / SUM(salary::numeric)), 10) AS so_per_$
FROM salaries AS s
INNER JOIN pitching AS pt USING (playerid)
INNER JOIN people AS p USING (playerid)
WHERE
    s.yearid = 2016
    AND gs >= 10
GROUP BY name
ORDER BY so_per_$;


-- USING HAVING SUM(gs) >= 10 instead of including in WHERE clause
-- pitchers who started 10 or more games for any team in 2016
SELECT
    namefirst || ' ' || namelast AS name,
    SUM(salary) AS salary,
    SUM(so) AS strikeouts,
    SUM(gs) AS games_started,
    ROUND((SUM(so::numeric) / SUM(salary::numeric)), 10) AS so_per_$
FROM salaries AS s
INNER JOIN pitching AS pt USING (playerid)
INNER JOIN people AS p USING (playerid)
WHERE
    s.yearid = 2016
GROUP BY name
HAVING SUM(gs) >=10
ORDER BY so_per_$;


-- Zack Greinke was the least efficient at 0.0000048768 strikeouts per dollar
-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.

WITH hofers AS (SELECT DISTINCT playerid, yearid
    FROM halloffame
    WHERE inducted = 'Y'
  ),
three_k_hitters AS (SELECT playerid
    FROM batting
    GROUP BY playerid
    HAVING SUM(h) >= 3000
  )
SELECT
  p.namefirst || ' ' || p.namelast AS player_name,
  SUM(b.h) AS career_hits,
  MAX(hof.yearid) AS hof_induction_year
FROM people AS p
INNER JOIN batting AS b USING(playerid)
INNER JOIN three_k_hitters USING(playerid)
LEFT JOIN hofers AS hof USING(playerid)
GROUP BY
    player_name
ORDER BY
  career_hits DESC;

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.


WITH hitters AS (SELECT
    player_team_hits.playerid,
    player_team_hits.teamid,
    player_team_hits.hits
FROM (SELECT
        playerid,
        teamid,
        SUM(h) AS hits
    FROM batting
    GROUP BY playerid, teamid
    HAVING SUM(h) >= 1000
) AS player_team_hits
WHERE player_team_hits.playerid IN (
        SELECT playerid
        FROM (
            SELECT playerid, teamid, SUM(h) AS hits
            FROM batting
            GROUP BY playerid, teamid
            HAVING SUM(h) >= 1000
        ) AS inner_player_team_hits
        GROUP BY playerid
        HAVING COUNT(teamid) >= 2
    )
ORDER BY playerid),

teamnames AS (
    SELECT DISTINCT teamid, name
    FROM teams
)

SELECT namefirst||' '||namelast AS playername, h.teamid AS team, h.hits AS hits
FROM people AS p
INNER JOIN hitters AS h
USING(playerid);


-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

WITH MaxHRByPlayer AS (
    SELECT playerid, MAX(hr) AS max_hr
    FROM batting
    GROUP BY playerid
  ),
  YearOfMaxHR AS (
    SELECT
      b.playerid,
      b.yearid,
      b.hr,
      m.max_hr
    FROM batting AS b
    INNER JOIN MaxHRByPlayer AS m USING(playerid)
    WHERE b.hr = m.max_hr
  )
SELECT
  namefirst||' '||namelast AS playername,
  max_hr
FROM YearOfMaxHR
LEFT JOIN people AS p USING(playerid)
WHERE yearid = 2016
    AND hr <> 0
ORDER BY max_hr DESC;

-- After finishing the above questions, here are some open-ended questions to consider.
-- **Open-ended questions**
-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

-- there's a weak positive correlation between a team's yearly payroll and wins (0.3423)
WITH yearly_payroll AS (
    SELECT s.yearid AS yearid, t.name AS teamname, t.w AS win, t.l AS loss, SUM(s.salary) AS team_payroll
    FROM salaries AS s
        INNER JOIN teams AS t USING (teamid, yearid)
    WHERE yearid >= 2000
    GROUP BY yearid, teamname, win, loss
    ORDER BY yearid
) 
SELECT 
    CORR(win, team_payroll) AS salary_wins_correlation
FROM yearly_payroll;


-- 12. In this question, you will explore the connection between number of wins and attendance.
    -- a. Does there appear to be any correlation between attendance at home games and number of wins?
SELECT *
FROM homegames
ORDER BY attendance DESC;

-- there appears to be a weak postive correlation between home attendance and wins (0.1665)
WITH home_attendance AS (
    SELECT 
        h.year AS yearid, 
        t.name AS teamname,
        t.w AS win,
        SUM(h.attendance) AS attendance
    FROM homegames AS h
        INNER JOIN teams AS t ON t.teamid = h.team
    GROUP BY h.year, teamname, t.w
)
SELECT CORR(attendance, win)
FROM home_attendance;

    -- b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the  playoffs means either being a division winner or a wild card winner.

-- organizes and cleans, and gets the difference in attendance btwn each year, but doesn't do anything to analyze or aggregate
WITH filtered AS (
    SELECT t.name AS teamname,
        t.yearid AS yearid,
        CASE
            WHEN divwin = 'Y' THEN 'Y'
            WHEN wcwin = 'Y' THEN 'Y'
            ELSE 'N'
        END AS made_playoffs,
        t.wswin AS world_series_w,
        h.attendance AS attendance
    FROM teams AS t
        INNER JOIN homegames AS h ON t.teamid = h.team
        AND t.yearid = h.year
    WHERE t.wswin IS NOT NULL
        OR t.wcwin IS NOT NULL
        AND t.lgid IN ('AL', 'NL')
    GROUP BY t.name, t.yearid, t.wswin, t.divwin, t.wcwin, h.attendance
    -- ORDER BY teamname ASC,
    --     yearid ASC
)

SELECT teamname, 
    yearid, 
    made_playoffs, 
    world_series_w, 
    attendance, 
    LAG(attendance, 1) 
        OVER(PARTITION BY teamname ORDER BY yearid) AS prev_yr_att,
    attendance - (LAG(attendance, 1) 
        OVER(PARTITION BY teamname ORDER BY yearid)) AS diff
FROM filtered;


-- gives the average difference in attendance after a WS winn compared to non ws win years 
-- really seems more like baseball as a whole is growing and that a WS win doesn't directly mean more attendance the following year by this analysis.
WITH filtered AS (
    SELECT t.name AS teamname,
           t.yearid AS yearid,
           CASE
               WHEN divwin = 'Y' THEN 'Y'
               WHEN wcwin = 'Y' THEN 'Y'
               ELSE 'N'
           END AS made_playoffs,
           t.wswin AS world_series_w,
           h.attendance AS attendance
    FROM teams AS t
        INNER JOIN homegames AS h ON t.teamid = h.team
        AND t.yearid = h.year
    WHERE (t.wswin IS NOT NULL OR t.wcwin IS NOT NULL)
        AND t.lgid IN ('AL', 'NL')
    GROUP BY t.name, t.yearid, t.wswin, t.divwin, t.wcwin, h.attendance
),
attendance_changes AS (
    SELECT teamname, 
           yearid, 
           made_playoffs, 
           world_series_w, 
           attendance, 
           LAG(attendance, 1) OVER(PARTITION BY teamname ORDER BY yearid) AS prev_yr_att,
           attendance - LAG(attendance, 1) OVER(PARTITION BY teamname ORDER BY yearid) AS diff
    FROM filtered
),
yearly_changes AS (
    SELECT teamname,
           yearid,
           world_series_w,
           prev_yr_att,
           diff,
           CASE 
               WHEN LAG(world_series_w, 1) OVER(PARTITION BY teamname ORDER BY yearid) = 'Y' THEN 'After WS Win' 
               ELSE 'Other Years' 
           END AS year_type
    FROM attendance_changes
)
SELECT 
    year_type,
    AVG(diff) AS avg_attendance_change,
    COUNT(yearid) AS num_years
FROM yearly_changes
WHERE prev_yr_att IS NOT NULL
GROUP BY year_type;

-- For each year i need to calculate the difference in attendance between that year and the following year. 
-- I need to correlate if the team with wswin has a higher difference than the other teams. 
-- what about diff of diff? would that give a better indication of whether the wswin causes attendance spike? 


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?

-- left hander rarity --
--------------------------------------------------------------------------------
-- this gives the number of left handed pitchers and right handed pitchers
SELECT 
    throws, 
    COUNT(DISTINCT playerid) AS n_pitchers
FROM people
    INNER JOIN pitching USING(playerid)
WHERE throws IS NOT NULL
GROUP BY throws;


-- wrong handers vs right handers -- 
--------------------------------------------------------------------------------
-- this gives n cy young winners and pct of cy young winners by hand
WITH cy_young_awards AS (
    SELECT * 
    FROM awardsplayers
    WHERE awardid = 'Cy Young Award'
)
SELECT 
    throws, 
    COUNT(playerid) AS n_players,
    COUNT(playerid) / (SELECT COUNT(playerid)::NUMERIC FROM cy_young_awards)::NUMERIC * 100 AS pct_cy_young_winners
FROM people AS p
    INNER JOIN cy_young_awards AS cya USING(playerid)
    GROUP BY throws;


-- Cy Young Awards --
-------------------------------------------------------------------------------
-- distinct cy young winners from the awards table and total distinct pitchers from the pitching table grouped by hand. To make not distinct and count basically by season, delete the DISTINCT calls in the SELECT statement
-- around 1.5% of left handed pitchers won the cy young award, and around 1.3% of right handed pitchers won the cy young award. 
WITH cy_young AS(
    WITH cy_s AS (
        SELECT playerid, yearid, awardid
        FROM awardsplayers
        WHERE awardid = 'Cy Young Award'
            AND yearid > 1955
    )

    SELECT
        throws,
        pt.playerid,
        pt.yearid,
        CASE WHEN awardid = 'Cy Young Award' THEN 'W' ELSE NULL END AS cy_young_winner
    FROM pitching AS pt
        LEFT JOIN cy_s AS cy ON pt.playerid = cy.playerid AND pt.yearid = cy.yearid AND awardid = 'Cy Young Award' 
        LEFT JOIN people AS p ON pt.playerid = p.playerid 
    WHERE pt.yearid > 1955
    GROUP BY throws, pt.playerid, pt.yearid, cy.awardid
    ORDER BY pt.yearid
)
SELECT 
    throws,
    COUNT(DISTINCT playerid) AS n_pitchers,
    COUNT(DISTINCT CASE WHEN cy_young_winner = 'W' THEN playerid END) AS cy_young_winners,
    ROUND(COUNT(DISTINCT CASE WHEN cy_young_winner = 'W' THEN playerid END)::NUMERIC / COUNT(DISTINCT playerid) * 100, 2) || '%' AS pct_cy_young_winners
FROM cy_young
GROUP BY throws;


-- Hall of famers --
--------------------------------------------------------------------------------

-- share of hofers (pitchers) for handedness
SELECT 
    throws, 
    COUNT(DISTINCT playerid) AS n_pitchers
FROM halloffame
    LEFT JOIN people AS p USING(playerid)
    INNER JOIN pitching AS pt USING(playerid)
WHERE inducted = 'Y' AND throws IS NOT NULL
GROUP BY throws;


--------------------------------------------------------------------------------

-- this gives a table with comparison of righties vs lefties in terms of strikeouts, strikouts per innings pitched, hall of fame induction, and share of pitchers per hand

WITH hof_pitchers AS (
    SELECT DISTINCT playerid,
        throws
    FROM people AS p
        INNER JOIN halloffame AS hof USING (playerid)
        INNER JOIN pitching AS pt USING (playerid)
    WHERE inducted = 'Y'
)
SELECT p.throws,
    SUM(so) AS total_strikeouts,
    SUM(ipouts / 3) AS innings_pitched,
    ROUND(AVG(era::NUMERIC), 2) AS avg_era,
    ROUND(SUM(so::NUMERIC) / SUM(ipouts::NUMERIC / 3), 2) AS so_per_ip,
    COUNT(DISTINCT hof.playerid) AS hofers,
    ROUND(
        COUNT(DISTINCT playerid)::NUMERIC / (
            SELECT COUNT(DISTINCT playerid)::NUMERIC
            FROM hof_pitchers
        ) * 100,
        2
    )::TEXT || '%' AS pct_hof
FROM pitching AS pt
    LEFT JOIN people AS p USING(playerid)
    LEFT JOIN awardsplayers AS ap USING(playerid, yearid)
    INNER JOIN hof_pitchers AS hof USING(playerid)
WHERE p.throws IS NOT NULL
GROUP BY p.throws;


-- analysis --
--------------------------------------------------------------------------------
-- these stats suggest it's not exactly a given that a lefty is better than a righty. lefties make up about a quarter of the hall of fame, while being about a quarter of total pitchers altogether, so not interesting. they have a slightly higher avg era, but a slighlty higher soip. 
-- around 1.5% of lefties have won the cy young, and around 1.3% of righties have won the cy young, although about a third of cy young winners were lefties, so that's something considering they make up only about a fourth of all pitchers.  