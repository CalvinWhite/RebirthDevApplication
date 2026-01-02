Config = {}

Config.Cooldown = 45 * 60 -- 45 minutes
Config.SecretNumber = "555-0199" -- NOTE:  I AM PLANNING TO HAVE THIS NUMBER RANDOMISED EVERY SO OFTEN SO PLAYERS CANT GET THE NUMBER AND KEEP CALLING IT AFTER THE COOLDOWN ENDS , WOULD ENCOURAGE PLAYERS TO DO MORE CRIME TO GET A NEW NUMBER 

-- Locations
-- NOTE: I WILL ADD ALL THE LOCATIONS FOR THE PHONE BOXES LATER SO THE NUMBER CAN BE CALLED FROM ANY PHONEBOX IN THE GAME, NOT THIS SPECIFIC ONE. 
-- NOTE: I NEED TO ADD A LIST OF DIFFERENT POSSIBLE LOCATIONS FOR THE MEETINGS AND DROP OFFS SO ITS DIFFERENT EACH TIME, SO FAR I JUST HAVE THESE AS A TEST
Config.PhoneBox = vector3(1156.3506, -776.3573, 57.5987)
Config.MeetingSpot = vector4(-487.2021, -399.9059, 34.5466, 304.1590)
Config.ArtScene = vector4(-342.3137, 214.9405, 87.2941, 88.9789)
Config.DropOff = vector4(-1569.3625, -453.2889, 35.9824, 270.8479)
Config.MoneyStash = vector3(-1096.2, -1495.1, 4.9)

-- Pickup point 
Config.ArtLootPoint = vector4(-352.8136, 214.5186, 86.6988, 33.9105)

-- Target sizes
Config.ZoneSize = {
    phone  = {1.2, 1.2},
    note   = {1.2, 1.2},
    drop   = {1.8, 1.8},
    stash  = {1.4, 1.4},
    pickup = {1.3, 1.3},
}

-- Models
Config.VanModel = `pony`
Config.NpcModel = `s_m_m_dockwork_01`

-- Guard
-- NOTE: I PLAN TO ADJUST THIS / RANDOMISE THE SECURITY 'DIFFICULTY' THAT WILL ALSO SCALE THE PAYOUT UP OR DOWN FOR THE MONEY REWARD FOR THE CRIME
Config.GuardModel = `s_m_m_security_01`
Config.GuardWeapon = `WEAPON_PISTOL`
Config.GuardAggroDistance = 8.0

-- Props
Config.ArtPickupCrateProp = `prop_box_wood01a`
Config.DropCrateProp = `prop_box_wood01a`

-- Item reward
-- NOTE: IF YOU GUYS RUN THIS CODE TO TEST IT PLEASE CHANGE THIS ITEM TO SOMETHING COMPATIBLE WITH YOUR INVENTORY SYSTEM BUT I HAVENT USED QBOX SO IM NOT SURE? IF YOU USE QBCORE CHANGE TO 'ROLEX' OR SOMETHING JUST TO TEST
Config.ArtItem = "artwork"
Config.ArtItemAmount = 1
Config.CrateCount = 1

Config.Voice = {
    voice1 = "calvin_artheistvoice1",
    voice2 = "calvin_artheistvoice2",
    wrong  = "calvin_artheistvoice3",
}

Config.VoiceLengthMs = {
    voice1 = 21000,
    voice2 = 25000,
    wrong  = 7000,
}

Config.WaypointDelayMs = 11000

Config.Debug = true

