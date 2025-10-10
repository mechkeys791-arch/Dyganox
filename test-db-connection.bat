@echo off
echo Testing PostgreSQL connection...
echo.
echo Endpoint: database-1-forpromechapp.cw52wo446izi.us-east-1.rds.amazonaws.com
echo Database: postgres
echo Username: postgres_ForPro
echo.
echo Testing with psql (if installed)...
psql -h database-1-forpromechapp.cw52wo446izi.us-east-1.rds.amazonaws.com -p 5432 -U postgres_ForPro -d postgres
pause

