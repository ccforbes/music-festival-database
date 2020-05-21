-- MUSIC FESTIVAL CODE

----------------------------------------------------------------------------THE FOLLOWING CODE IS BY CHRIS FORBES
-- STORED PROCEDURE FOR TABLE CONTACT
create procedure cforbes_insertContact
	@Email varchar(50),
	@Mobile_Phone nchar(10),
	@Work_Phone nchar(10) 
	as

	begin tran newContact
	insert into Contact(Email, [Mobile Phone], [Work Phone])
	values (@Email, @Mobile_Phone, @Work_Phone)
	commit tran newContact
go

create procedure cforbes_insertCost
	@FlatFee numeric(10, 2),
	@HourlyFee numeric(10, 2)
	as

	begin tran newCost
	insert into Cost(CostFlatFee, CostHourlyFee)
	values (@FlatFee, @HourlyFee)
	commit tran newCost
go

-- STORED PROCEDURE FOR TABLE AGENT
create procedure cforbes_insertAgent
	@Fname varchar(50),
	@Lname varchar(50),
	--dependent info
	@Email varchar(50)
	as

	declare @Contact_ID int
	set @Contact_ID = (select ContactID from Contact where Email = @Email)

	begin tran newAgent
	insert into Agent(AgentFName, AgentLName, ContactID)
	values (@Fname, @Lname, @Contact_ID)
go

-- STORED PROCEDURE FOR TABLE TALENT
create procedure cforbes_insertTalent
	@Name varchar(50),
	@DOB datetime,
	@Residence varchar(50),
	--dependent info
	@FlatFee numeric(10,2),
	@HourlyFee numeric(10,2),
	@Email varchar(50),
	@Genre_Name varchar(50),
	@Subgenre_Name varchar(50),
	@Talent_Type varchar(50)
	as

	declare @Cost_ID int
	set @Cost_ID = (
	select CostID
	from Cost
	where CostFlatFee = @FlatFee
	and CostHourlyFee = @HourlyFee
	)

	declare @Agent_ID int
	set @Agent_ID = (
	select A.AgentID
	from Agent A
	join Contact C on A.ContactID = C.ContactID
	where C.Email = @Email
	)

	declare @Genre_ID int
	set @Genre_ID = (
	select GenreID
	from Genre
	where GenreName = @Genre_Name
	)

	declare @Subgenre_ID int
	set @Subgenre_ID = (
	select SubGenreID
	from SubGenre
	where SubGenreName = @Subgenre_Name
	)

	declare @TT_ID int
	set @TT_ID = (
	select TalentTypeID
	from TalentType
	where TalentTypeName = @Talent_Type
	)


	begin tran newTalent
	insert into Talent(TalentName, TalentDOB, TalentResidence, CostID, TalentTypeID, AgentID, GenreID, SubGenreID)
	values (@Name, @DOB, @Residence, @Cost_ID, @TT_ID, @Agent_ID, @Genre_ID, @Subgenre_ID)
	commit tran newTalent
go



-- THE FOLLOWING COMPLEX QUERIES IN A VIEW ARE BY CHRIS FORBES

/*Which talent has the most amount of albums that also have the
shortest set length?
*/

create view MostAlbumsWithShortestSetLength
as
	select top 1 T.TalentID, T.TalentName, S.SetLengthMinutes, NumOfAlbums
	from Talent T
		join Booking B on T.TalentID = B.TalentID
		join [Set] S on B.SetID = S.SetID

		join (
			select T2.TalentID, T2.TalentName, count(A.AlbumID) as NumOfAlbums
			from Talent T2
				join Album A on T2.TalentID = A.TalentID
			group by T2.TalentID, T2.TalentName
		) as SubQ2 on T.TalentID = SubQ2.TalentID

	order by NumOfAlbums, S.SetLengthMinutes desc
go


/*
Which agent has the most talents that also make the most money?
*/
create view AgentWithMostTalentsWithMostMoney
as
	select top 1 A.AgentFullName, TotalCost, count(T.TalentID) as NumTalents
	from Agent A
		join Talent T on A.AgentID = T.AgentID
	
		join (
			select T2.TalentID, sum(C.CostFlatFee + (C.CostHourlyFee * S.SetLengthMinutes)) as TotalCost
			from Cost C
				join Talent T2 on C.CostID = T2.TalentID
				join Booking B on T2.TalentID = B.TalentID
				join [Set] S on B.SetID = S.SetID
			group by T2.TalentID
		) as SubQ2 on T.TalentID = SubQ2.TalentID
	
	group by A.AgentFullName, TotalCost
	order by NumTalents desc
go

-- THE FOLLOWING COMPUTED COLUMNS ARE BY CHRIS FORBES
create function cforbes_totalArtistCost(@pk int) returns numeric(10,2)
as
begin
	declare @ret numeric(10,2)
	set @ret = (
		select sum(C.CostFlatFee + (C.CostHourlyFee * S.SetLengthMinutes))
		from Cost C
			join Talent T on C.CostID = T.TalentID
			join Booking B on T.TalentID = B.TalentID
			join [Set] S on B.SetID = S.SetID
		where T.TalentID = @pk
	)
	return @ret
end
go

alter table Talent
add TotalArtistCost as (dbo.cforbes_totalArtistCost(TalentID))
go


create function cforbes_AgentFullName(@pk int) returns varchar(50)
as
begin
	declare @ret varchar(50)
	set @ret = (
		select AgentFName + ' ' + AgentLName
		from Agent
		where AgentID = @pk
	)
	return @ret
end
go

alter table Agent
add AgentFullName as (dbo.cforbes_AgentFullName(AgentID))
go

-- THE FOLLOWING BUSINESS RULES ARE BY CHRIS FORBES
/*
A Talent can't have a subgenre that doesn't fall under their
respective genre
*/
alter function cforbes_NoIncorrectSubgenres() returns int
as
begin
	declare @ret int = 0
	if exists (
		select *
		from Talent T
			join Genre G on T.GenreID = G.GenreID
			join SubGenre SG on T.SubGenreID = SG.SubGenreID
		where SG.GenreID <> G.GenreID
	)
	begin
		set @ret = 1
	end
	return @ret
end
go

alter table Talent
add constraint CK_NoIncorrectSubGenresForTalent
check (dbo.cforbes_NoIncorrectSubgenres() = 0)
go

/*
No booking can have a set for longer than 10 hours
*/
alter function cforbes_NoSetLengthLongerThan12Hours() returns int
as
begin 
	declare @ret int = 0
	if exists (
		select *
		from Booking B
			join [Set] S on B.SetID = S.SetID
		where S.SetLengthMinutes > 600
	)
	begin
		set @ret = 1
	end
	return @ret
end
go

alter table Booking
add constraint CK_NoSetLongerThan12Hours
check (dbo.cforbes_NoSetLengthLongerThan12Hours() = 0)

----------------------------------------------------------------------------THE FOLLOWING CODE IS BY JAVARIA YOUSEF
--STORED PROCEDURES
/* Add a new festival to an existing Budget and Theme*/
CREATE PROCEDURE newFestival
@FestivalName varchar(50),
@FestivalLocation varchar(500),
@FestivalCapacity INT,
@Ages INT,
@FestivalBeginDate date,
@FestivalEndDate date,
@VendorBudget numeric(10,2),
@MerchBudget numeric(10,2),
@HeadlinerBudget numeric(10,2),
@OpenerBudget numeric(10,2),
@ThemeName varchar(50)

AS

DECLARE
@BudgetID INT,
@ArtistBudgetID INT,
@ThemeID INT

SET @ArtistBudgetID = (SELECT ArtistBudgetID FROM ArtistBudget WHERE HeadlinerBudget = @HeadlinerBudget
    AND OpenerBudget = @OpenerBudget)
SET @BudgetID = (SELECT BudgetID FROM Budget WHERE VendorBudget = @VendorBudget
    AND MerchBudget = @MerchBudget
    AND AristBudgetID = @ArtistBudgetID)
SET @ThemeID = (SELECT ThemeID FROM Theme WHERE ThemeName = @ThemeName)

BEGIN TRANSACTION G1
INSERT INTO Festival (FestivalName, FestivalLocation, FestivalCapacity, Ages, FestivalBeginDate,
                      FestivalEndDate, BudgetID, ThemeID)
VALUES (@FestivalName, @FestivalLocation, @FestivalCapacity, @Ages, @FestivalBeginDate,
       @FestivalEndDate, @BudgetID, @ThemeID)
COMMIT TRANSACTION G1

/* Add a new budget to an existing Artist Budget */
CREATE PROCEDURE newBudget
@VendorBudget numeric(10, 2),
@MerchBudget numeric(10, 2),
@HeadlinerBudget numeric (10, 2),
@OpenerBudget numeric(10, 2)

AS

DECLARE
@ArtistBudgetID INT

SET @ArtistBudgetID = (SELECT ArtistBudgetID FROM ArtistBudget WHERE HeadlinerBudget = @HeadlinerBudget
    AND OpenerBudget = @OpenerBudget)

BEGIN TRANSACTION G1
INSERT INTO Budget (VendorBudget, MerchBudget, ArtistBudgetID)
VALUES (@VendorBudget, @MerchBudget, @ArtistBudgetID)
COMMIT TRANSACTION G1

-- THE FOLLOWING COMPLEX QUERIES IN A VIEW ARE BY JAVARIA YOUSEF
CREATE VIEW allAgesSummerFestivals
AS

SELECT F.FestivalName
    FROM Festival F
    JOIN Set S ON F.FestivalID = S.FestivalID
    JOIN Booking B ON S.SetID = B.SetID
    JOIN Talent T ON B.TalentID = T.TalentID
    JOIN TalentType TT ON T.TalentTypeID = TT.TalentTypeID

JOIN

    (SELECT F.FestivalName
    FROM Festival F
    WHERE F.Ages IS NULL
    AND MONTH(F.FestivalBeginDate) >= 6
    AND MONTH(F.FestivalBeginDate) <= 9) AS SubQ1 ON F.FestivalName = SubQ1.FestivalName

    WHERE TT.TalentType = 'Solo'
    AND YEAR(T.TalentDOB) BETWEEN 1990 AND 1999
    GROUP BY F.FestivalName
    HAVING COUNT(B.BookingID) >= 2
    ORDER BY F.FestivalName ASC

/* View all festivals in alphabetical order that have booked at least three female solo artists
   who have won 2 or more accolades in 2012*/
CREATE VIEW threeFemaleArtistTwoAccolades
AS

SELECT F.FestivalName
    FROM Festival F
    JOIN Set S ON F.FestivalID = S.FestivalID
    JOIN Booking B ON S.SetID = B.SetID
    JOIN Talent T ON S.TalentID = T.TalentID
    JOIN Album A ON T.TalentID = A.TalentID
    JOIN Accolades AC ON A.AlbumID = AC.AlbumID

JOIN

    (SELECT F.FestivalName
    FROM Festival F
    JOIN Set S ON F.FestivalID = S.FestivalID
    JOIN Booking B ON S.SetID = B.SetID
    JOIN Talent T ON S.TalentID = T.TalentID
    JOIN TalentType TT ON T.TalentTypeID = TT.TalentTypeID
    WHERE TT.TalentTypeName = 'Solo'
    AND T.TalentGender = 'Female'
    GROUP BY F.FestivalName
    HAVING COUNT(B.BookingID) >= 3) AS SubQ1 ON F.FestivalName = SubQ1.FestivalName

    WHERE AC.AccoladeYear = '2012'
    GROUP BY F.FestivalName
    HAVING COUNT(AC.AccoladeID) >= 2
    ORDER BY F.FestivalName ASC


-- THE FOLLOWING COMPUTED COLUMNS ARE BY JAVARIA YOUSEF
CREATE FUNCTION festivalLength(@PK INT)
RETURNS INTEGER
AS
BEGIN
        DECLARE @RET INTEGER = (
            SELECT DATEDIFF(DAY, FestivalBeginDate, FestivalEndDate)
            FROM Festival
            WHERE FestivalID = @PK
            )
RETURN @RET
END
GO

ALTER TABLE Festival
ADD Festival_Length AS (dbo.festivalLength(FestivalID))

/* Total Artist Budget */
ALTER FUNCTION totalArtistBudget(@PK INT)
RETURNS NUMERIC(10, 2)
AS
BEGIN
        DECLARE @RET NUMERIC = (
            SELECT SUM(HeadlinerBudget + OpenerBudget)
            FROM ArtistBudget
            WHERE ArtistBudgetID = @PK
            )
RETURN @RET
END
GO

ALTER TABLE ArtistBudget
ADD Total_Artist_Budget AS (dbo.totalArtistBudget(ArtistBudgetID))

-- THE FOLLOWING BUSINESS RULES ARE BY JAVARIA YOUSEF

/* Festival end date cannot be before festival begin date */
CREATE FUNCTION festivalDateRule()
RETURNS INTEGER
AS
BEGIN
      DECLARE @RET INTEGER = 0
        IF EXISTS (
            SELECT *
            FROM Festival F
            WHERE DATEDIFF(DAY, F.FestivalBeginDate, F.FestivalEndDate) < 1
            )
        BEGIN
            SET @RET = 1
        END

RETURN @RET
END
GO

ALTER TABLE Festival
ADD CONSTRAINT CK_NoBadDates
CHECK (dbo.festivalDateRule() = 0)

/* Set end time cannot be before set begin time */
CREATE FUNCTION setTimeRule()
RETURNS INTEGER
AS
BEGIN
      DECLARE @RET INTEGER = 0
        IF EXISTS (
            SELECT *
            FROM Set S
            WHERE DATEDIFF(HOUR, S.BeginTime, S.EndTime) < 1
            )
        BEGIN
            SET @RET = 1
        END
RETURN @RET
END
GO

ALTER TABLE Set
ADD CONSTRAINT CK_NoBadSetTime
CHECK (dbo.setTimeRule() = 0)

----------------------------------------------------------------------------THE FOLLOWING CODE IS BY AARON ONG
-- STORED PROCEDURES

-- TABLE: ACCOLADES
alter PROCEDURE ongINSERTACCOLADES 
@Award_Name varchar(50), 
@Streaming_Name varchar(50), 
@Radio_Name varchar(50), 
@AccoladeYear char(4), 
@Feature_Name varchar(50),
@Album_Name varchar(50)


AS 
DECLARE @A_Name INT,
		@S_Name INT, 
		@R_Name INT,
		@F_Name INT,
		@AL_Name INT
		
SET @A_Name = (SELECT AwardID FROM Awards WHERE AwardName = @Award_Name) 
SET	@S_Name = (SELECT StreamingID FROM Streaming WHERE StreamingServiceName = @Streaming_Name) 
SET @R_Name = (SELECT RadioID FROM Radio WHERE RadioStationName = @Radio_Name) 
SET @F_Name = (SELECT FeatureID FROM Feature WHERE FeatureName = @Feature_Name)
SET @AL_Name = (SELECT AlbumID FROM Album WHERE AlbumTitle = @Album_Name) 

BEGIN TRANSACTION A1
INSERT INTO Accolades(AwardID, StreamingID, RadioID, AccoladeYear, FeatureID, AlbumID) 
VALUES (@A_Name, @S_Name, @R_Name, @AccoladeYear, @F_Name, @AL_Name) 
COMMIT TRANSACTION A1
GO 

-- TABLE: FEATURE
CREATE PROCEDURE ongINSERTFEATURE
@Talent_Name varchar(50),
@Song_Title varchar(50),
@Feature_Name varchar(50)

AS 
DECLARE @T_Name INT, 
		@S_Title INT

SET @T_Name = (SELECT TalentID FROM Talent WHERE TalentName = @Talent_Name) 
SET @S_Title = (SELECT SongID FROM Song WHERE SongTitle = @Song_Title) 

BEGIN TRANSACTION A1
INSERT INTO Feature(TalentID, SongID, FeatureName) 
VALUES (@T_Name, @S_Title, @Feature_Name) 
COMMIT TRANSACTION A1
GO 

-- THE FOLLOWING COMPLEX QUERIES IN A VIEW ARE BY AARON ONG

CREATE VIEW TalentsOver20000Grammy
AS

select T.TalentName, AWT.AwardTypeName
FROM Talent T 
JOIN Album A on T.AlbumID = A.AlbumID 
JOIN Accolades AL on A.AlbumID = AL.AlbumID 
JOIN Streaming S on AL.StreamingID = S.StreamingID 
JOIN Awards AW on AL.AwardID = AW.AwardID 
JOIN AwardType AWT on AW.AwardTypeID = AWT.AwardTypeID
WHERE S.StreamingNumbers > 20000
AND AWT.AwardTypeName = 'Grammy' 
GROUP BY T.TalentName, AWT.AwardTypeName, S.StreamingNumbers
ORDER BY S.StreamingNumbers DESC 


--QUERY TO FIND TALENTS FROM GENRE POP WITH RADIOPLAYS FROM MOVIN 92.5 WITH AT LEAST 2 AWARDS
CREATE VIEW POPMOVIN92.5
AS

SELECT T.TalentName, Count(AW.AwardID) as NumAwards 
FROM Talent T 
JOIN Album A on T.AlbumID = A.AlbumID 
JOIN Accolades AL on A.AlbumID = AL.AlbumID 
JOIN Radio R on AL.RadioID = R.RadioID 
JOIN Awards AW on AL.AwardID = AW.AwardID
JOIN Genre G on T.GenreID = G.GenreID 
WHERE G.GenreName = 'Pop'
AND R.RadioStationName = 'Movin 92.5' 
GROUP BY T.TalentName
HAVING Count(AW.AwardID) >= 2

-- THE FOLLOWING COMPUTED COLUMNS ARE BY AARON ONG

--computed column calculating total artist plays--
CREATE FUNCTION CALC_TotArtistPlays(@PK INT) 
RETURNS numeric(18,0) 
AS 
BEGIN 
	DECLARE @RET numeric(18,0) = 
	(SELECT SUM (R.RadioPlays + S.StreamingNumbers) 
		FROM Streaming S
			JOIN Accolades A on S.StreamingID = A.StreamingID
			JOIN Radio R on A.RadioID = R.RadioID
			JOIN Album AL on A.AlbumID = AL.AlbumID
			JOIN Talent T on AL.TalentID = T.TalentID 
			WHERE T.TalentID = @PK)
		RETURN @RET 
	END 
	GO 

	ALTER TABLE Talent
	ADD TotalArtistPlays
	AS (dbo.CALC_TotArtistPlays(TalentID))

--computed column calculating total artist awards--
CREATE FUNCTION TotalArtistAwardsYEAR(@PK INT) 
RETURNS numeric(10,0) 
AS 
BEGIN 
	DECLARE @Ret numeric(10,0) = 
		(SELECT COUNT (A.AwardID) 
		FROM Awards A
			JOIN Accolades AL on A.AwardID = AL.AwardID
			JOIN Album ALB on AL.AlbumID = ALB.AlbumID
			JOIN Talent T on ALB.TalentID = T.TalentID
			WHERE T.TalentID = @PK)
		RETURN @RET 
		END
		GO 
ALTER TABLE Talent
ADD TotalArtistAwardsYear
AS (dbo.TotalArtistAwardsYear(TalentID))

-- THE FOLLOWING BUSINESS RULES ARE BY AARON ONG

--business rule where streaming numbers and radio plays cannot be negative
CREATE FUNCTION NoNegativePlays() 
RETURNS INT 
AS
BEGIN 
	DECLARE @RET int = 0 
	IF EXISTS (select * from Streaming S
		JOIN Accolades A on S.StreamingID = A.StreamingID
		JOIN Radio R on A.RadioID = R.RadioID 
		WHERE S.StreamingNumbers < 0 
		AND R.RadioPlays < 0)
	BEGIN
		SET @RET = 1
	END 
	RETURN @RET
END 
GO

ALTER TABLE Accolades 
ADD CONSTRAINT NoNegativePlays
CHECK (dbo.NoNegativePlays() = 0) 

--business rule where an artist cannot be featured on their own song 
CREATE FUNCTION NoArtistFeatureOwnSong()
RETURNS INT 
AS
BEGIN 
	DECLARE @RET int = 0 
		IF EXISTS (select * from Feature F
		JOIN Accolades A on F.FeatureID = A.FeatureID
		JOIN Album AL on A.AlbumID = AL.AlbumID
		JOIN Talent T on AL.TalentID = T.TalentID 
	WHERE T.TalentName = F.FeatureName) 
	
	BEGIN 
		SET @RET = 1 
	END 
	RETURN @RET 
END 
GO

ALTER TABLE Talent
ADD CONSTRAINT NoArtistFeatureOwnSong 
CHECK (dbo.NoArtistFeatureOwnSong() = 0) 

----------------------------------------------------------------------------THE FOLLOWING CODE IS BY MARIA MATLICK
-- STORED PROCEDURES
-- TABLE: ALBUM
ALTER PROCEDURE mmatlick_album_data
@ALBUM_TITLE varchar(50),
@ALBUM_YEAR char(4),
@ALBUM_DESCR varchar(50),
@TALENT_NAME varchar(50)

AS

DECLARE @TALENT_ID INT
SET @TALENT_ID = (SELECT TalentID	
				  FROM Talent
				  WHERE TalentName = @TALENT_NAME)

BEGIN TRANSACTION M1
INSERT INTO ALBUM (AlbumTitle, AlbumYear, AlbumDescription, TalentID)
VALUES (@ALBUM_TITLE, @ALBUM_YEAR, @ALBUM_DESCR, @TALENT_ID)
COMMIT TRANSACTION M1
GO 
-- TABLE: BOOKING
ALTER PROCEDURE mmatlick_booking_data
@TALENT_NAME varchar(50),
@SET_BEGIN_TIME time,
@SET_END_TIME time

AS

DECLARE @SET_ID INT, @TALENT_ID INT

SET @SET_ID = (SELECT SetID
			   FROM [dbo].[Set]
			   WHERE BeginTime = @SET_BEGIN_TIME
				AND EndTime = @SET_END_TIME)

SET @TALENT_ID = (SELECT TalentID
					FROM Talent
					WHERE TalentName = @TALENT_NAME)

BEGIN TRANSACTION M2
INSERT INTO Booking (TalentID, SetID)
VALUES (@TALENT_ID, @SET_ID)
COMMIT TRANSACTION M2
GO
-- THE FOLLOWING COMPLEX QUERIES IN A VIEW ARE BY MARIA MATLICK

-- count the albums won Grammy's in 2018 by 
CREATE VIEW grammy_album_2018
AS

SELECT  COUNT (ALB.AlbumID) AS GrammyAlbums2018
FROM Album ALB
	JOIN Accolades ACC
		ON ALB.AlbumID = ACC.AlbumID
	JOIN Awards AWD
		ON ACC.AwardID = AWD.AwardID
	JOIN AwardType AWDT
		ON AWD.AwardTypeID = AWDT.AwardTypeID
WHERE ACC.AccoladeYear = '2018'
	AND AWDT.AwardTypeName = 'Grammy'

-- Count the number of artists to release grunge albums in 1991
CREATE VIEW grunge_albums_91
AS

SELECT A.AlbumYear, T.TalentName, SG.SubGenreName, A.AlbumTitle, COUNT (T.TalentID) AS NumArtists
FROM Album A
	JOIN Talent T
		ON A.TalentID = T.TalentID
	JOIN GENRE G
		ON T.GenreID = G.GenreID
	JOIN SubGenre SG
		ON G.GenreID = SG.GenreID
WHERE SG.SubGenreName = 'Grunge'
	AND A.AlbumYear = '1991'
GROUP BY A.AlbumYear, T.TalentName, SG.SubGenreName, A.AlbumTitle

-- THE FOLLOWING COMPUTED COLUMNS ARE BY MARIA MATLICK

-- Set length in minutes
ALTER FUNCTION mmatlick_set_length (@PK INT)
RETURNS NUMERIC (8,2)
AS
BEGIN
	DECLARE @RET NUMERIC (8,2) = (
		SELECT DATEDIFF(MINUTE, BeginTime, EndTime)
		FROM [dbo].[Set]
		WHERE SetID = @PK
	)
RETURN @RET
END
GO

ALTER TABLE [dbo].[Set]
ADD SetLengthMinutes 
AS (dbo.mmatlick_set_length(SetID))


--  Number of albums per talent
ALTER FUNCTION mmatlick_total_albums (@PK INT)
RETURNS INT
AS
BEGIN
	DECLARE @RET INT = (
				SELECT COUNT(ALBUMID)
				FROM Album
				WHERE TalentID = @PK
	)

RETURN @RET
END 
GO

ALTER TABLE Album
ADD TotalArtistAlbums 
AS (dbo.mmatlick_total_albums(TalentID))

-- THE FOLLOWING BUSINESS RULES ARE BY MARIA MATLICK
-- sets must be at least 30 minutes long
CREATE FUNCTION mmatlick_set_length_30()
RETURNS INT
AS
BEGIN
	DECLARE @RET Int = 0
		IF EXISTS (SELECT *
				   FROM [dbo].[Set] S
				   WHERE SetLengthMinutes < 30)
	BEGIN
		SET @RET = 1
	END
	RETURN @RET
END
GO

ALTER TABLE [Set]
ADD CONSTRAINT SetLength
CHECK (dbo.mmatlick_set_length() = 0)

-- Albums must have 7 songs 
CREATE FUNCTION mmatlick_album_length()
RETURNS INT
AS
BEGIN
	DECLARE @RET Int = 0
		IF EXISTS (SELECT *
				   FROM Song
				   HAVING COUNT(AlbumID) < 7)
	BEGIN
		SET @RET = 1
	END
	RETURN @RET
END
GO

ALTER TABLE Album
ADD CONSTRAINT NumSongs
CHECK (dbo.mmatlick_album_length() = 0)



