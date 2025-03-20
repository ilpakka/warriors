local DIFFICULTIES = {
    NORMAL = {
        name = "Normal",
        indicatorTime = 1.5,
        playerHealth = 100,
        damageMultiplier = 1
    },
    HARD = {
        name = "Hard",
        indicatorTime = 0.75,
        playerHealth = 100,
        damageMultiplier = 2
    },
    EXTREME = {
        name = "Extreme",
        indicatorTime = 0.3,
        playerHealth = 1,
        damageMultiplier = 1
    }
}

local difficultyPoints = {
    Normal = 10,
    Hard = 40,
    Extreme = 100
}

local difficultyMultipliers = {
    Normal = 1,
    Hard = 2,
    Extreme = 5
}

local currentDifficulty = DIFFICULTIES.NORMAL  -- This ensures it's never nil

local player = {
    health = 100,
    damage = 50,
    state = "idle",
    hit_time = 0,
    attack_time = 0,
    block_time = 0,
    block_type = nil,  -- Will store the type of block being performed
    death_time = 0
}
local enemy = {
    health = 100,
    max_health = 100,
    damage = 10,
    state = "idle",
    attack = nil,
    attack_time = 0,
    indicator_time = 1.5,
    hit_time = 0,
    idle_time = 0,
    death_time = 0,
    hit_delay = 0
}
local gameState = "menu"
local countdown = 2 -- Game start countdown
local counterKey = {overhead = "up", stab = "left", swing = "down"}
local score = 1 -- Score tracker
local playerInputLocked = false
local menuSelection = 1
local gameoverSelection = 1
local playerSprites = {}
local enemySprites = {}
local menuSprites = {}
local fonts = {}
local background
local sounds = {}
local music = {}
local currentMusic = nil
local difficultySelection = 1
local pauseSelection = 1
local pauseScreenshot = nil


local blockStartTime = 0  -- When the enemy indicator starts
local totalBlockScore = 0  -- Sum of all successful block reaction times


local highScores = {
    Normal = 0,
    Hard = 0,
    Extreme = 0
}


local function loadHighScores()
    if love.filesystem.getInfo("highscores.txt") then
        local content = love.filesystem.read("highscores.txt")
        for difficulty, score in content:gmatch("(%w+):(%d+)") do
            highScores[difficulty] = tonumber(score)
        end
    end
end

local function saveHighScores()
    local content = ""
    for difficulty, score in pairs(highScores) do
        content = content .. difficulty .. ":" .. score .. "\n"
    end
    love.filesystem.write("highscores.txt", content)
end

-- Game configuration
local CONFIG = {
    WINDOW = {
        WIDTH = 800,
        HEIGHT = 600,
        TITLE = "Warriors"
    },
    PLAYER = {
        INITIAL_HEALTH = 100,
        INITIAL_DAMAGE = 50,
        ATTACK_DURATION = 0.3,
        HIT_DURATION = 1.0,
        BLOCK_DURATION = 0.2,
        BLOCK_WINDOW = 0.2
    },
    ENEMY = {
        INITIAL_HEALTH = 100,
        INITIAL_DAMAGE = 10,
        HEALTH_INCREASE_PER_LEVEL = 20,
        DAMAGE_INCREASE_PER_LEVEL = 5,
        INDICATOR_TIME = 1.5,
        SPEED_INCREASE_FACTOR = 0.9,
        MIN_INDICATOR_TIME = 0.5,
        HIT_DURATION = 1.0,
        IDLE_DURATION = 1.0,
        DEATH_DURATION = 1.0,
        HIT_DELAY = 0.5
    },
    GAME = {
        COUNTDOWN_TIME = 2,
        DEATH_TRANSITION_TIME = 2
    },
    AUDIO = {
        MUSIC = {
            VOLUME = 0.7,
        },
        SFX = {
            VOLUME = 1.0,
        }
    }
}

-- Attack configurations
local ATTACKS = {
    overhead = { key = "up", indicator = "indicatorOverhead", sprite = "attackOverhead" },
    stab = { key = "left", indicator = "indicatorStab", sprite = "attackStab" },
    swing = { key = "down", indicator = "indicatorSwing", sprite = "attackSwing" }
}

-- Logger utility
local Logger = {
    INFO = "INFO",
    WARNING = "WARNING",
    ERROR = "ERROR",
    log = function(self, level, message)
        print(string.format("[%s][%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, message))
    end
}

-- Safe image loader
function safeLoadImage(path)
    local success, image = pcall(love.graphics.newImage, path)
    if success then
        return image
    else
        print("Error loading image: " .. path)
        return nil
    end
end

-- Safe audio loader
function safeLoadAudio(path, type)
    local success, audio = pcall(love.audio.newSource, path, type)
    if success then
        return audio
    else
        Logger:log(Logger.ERROR, "Error loading audio: " .. path)
        return nil
    end
end

-- Timer system
local timers = {}

local function updateTimers(dt)
    for i = #timers, 1, -1 do
        local timer = timers[i]
        timer.time = timer.time - dt
        if timer.time <= 0 then
            timer.callback()
            table.remove(timers, i)
        end
    end
end

local function addTimer(delay, callback)
    table.insert(timers, {
        time = delay,
        callback = callback
    })
end

-- AudioManager
local AudioManager = {
    playSound = function(name)
        if sounds[name] then
            local clone = sounds[name]:clone()
            clone:setVolume(CONFIG.AUDIO.SFX.VOLUME)
            clone:play()
        end
    end,

    playMusic = function(name)
        if music[name] and currentMusic ~= music[name] then
            if currentMusic then
                currentMusic:stop()
            end
            currentMusic = music[name]
            currentMusic:setVolume(CONFIG.AUDIO.MUSIC.VOLUME)
            currentMusic:setLooping(true)
            currentMusic:play()
        end
    end,

    stopMusic = function()
        if currentMusic then
            currentMusic:stop()
            currentMusic = nil
        end
    end
}

-- Loading
function love.load()
    -- SET FIXED WINDOW + TITLE
    love.window.setMode(CONFIG.WINDOW.WIDTH, CONFIG.WINDOW.HEIGHT)
    love.window.setTitle(CONFIG.WINDOW.TITLE)

    -- SET FONTS
    fonts.small = love.graphics.newFont(16)
    fonts.medium = love.graphics.newFont(32)
    fonts.large = love.graphics.newFont(48)
    fonts.gameover = love.graphics.newFont(40)

    -- GAME BACKGROUND
    background = safeLoadImage("assets/background/bg.png")

    -- MAIN MENU
    menuSprites.background = safeLoadImage("assets/menu/menubg.png")

    -- PLAYER SPRITES
    playerSprites.idle = safeLoadImage("assets/player/player_idle.png")
    playerSprites.hit = safeLoadImage("assets/player/player_hit.png")
    playerSprites.death = safeLoadImage("assets/player/player_death.png")

    playerSprites.attack = safeLoadImage("assets/player/player_attack.png")

    playerSprites.blockOverhead = safeLoadImage("assets/player/player_block_overhead.png")
    playerSprites.blockStab = safeLoadImage("assets/player/player_block_stab.png")
    playerSprites.blockSwing = safeLoadImage("assets/player/player_block_swing.png")


    -- ENEMY SPRITES
    enemySprites.idle = safeLoadImage("assets/enemy/enemy_idle.png")
    enemySprites.hit = safeLoadImage("assets/enemy/enemy_hit.png")
    enemySprites.death = safeLoadImage("assets/enemy/enemy_death.png")

    enemySprites.attackOverhead = safeLoadImage("assets/enemy/enemy_attack_overhead.png")
    enemySprites.attackStab = safeLoadImage("assets/enemy/enemy_attack_stab.png")
    enemySprites.attackSwing = safeLoadImage("assets/enemy/enemy_attack_swing.png")

    enemySprites.indicatorOverhead = safeLoadImage("assets/enemy/enemy_indicator_overhead.png")
    enemySprites.indicatorStab = safeLoadImage("assets/enemy/enemy_indicator_stab.png")
    enemySprites.indicatorSwing = safeLoadImage("assets/enemy/enemy_indicator_swing.png")

    -- Load music
    music.theme = safeLoadAudio("assets/audio/music/theme.ogg", "stream")
    music.battle = safeLoadAudio("assets/audio/music/battle_theme.ogg", "stream")
    
    -- Load sound effects
    sounds.menuSelect = safeLoadAudio("assets/audio/sfx/menu_select.ogg", "static")
    sounds.playerAttack = safeLoadAudio("assets/audio/sfx/player_attack.ogg", "static")
    sounds.playerHit = safeLoadAudio("assets/audio/sfx/player_hit.ogg", "static")
    sounds.playerDeath = safeLoadAudio("assets/audio/sfx/player_death.ogg", "static")
    sounds.enemyHit = safeLoadAudio("assets/audio/sfx/enemy_hit.ogg", "static")
    sounds.enemyDeath = safeLoadAudio("assets/audio/sfx/enemy_death.ogg", "static")

    -- Start menu music immediately
    AudioManager.playMusic("theme")

    loadHighScores()
end

-- State definitions
local States = {
    PLAYER = {
        IDLE = "idle",
        ATTACK = "attack",
        HIT = "hit",
        BLOCK = "block",
        DEATH = "death"
    },
    ENEMY = {
        IDLE = "idle",
        INDICATOR = "indicator",
        ATTACK = "attack",
        HIT = "hit",
        DEATH = "death"
    },
    GAME = {
        MENU = "menu",
        HOW_TO_PLAY = "howToPlay",
        DIFFICULTY = "difficulty",
        COUNTDOWN = "countdown",
        PLAYING = "playing",
        PAUSE = "pause",
        GAMEOVER = "gameover"
    }
}

local StateManager = {}

-- Define StateManager components
StateManager.game = {
    changeState = function(newState)
        if States.GAME[newState] then
            local oldState = gameState
            gameState = States.GAME[newState]
            
            -- Handle music changes
            if newState == "MENU" or newState == "GAMEOVER" then
                AudioManager.playMusic("theme")
            elseif newState == "PLAYING" then
                AudioManager.playMusic("battle")
            end
            
            Logger:log(Logger.INFO, string.format("Game state changed: %s -> %s", oldState, gameState))
        end
    end
}

StateManager.player = {
    changeState = function(newState, params)
        params = params or {}
        if States.PLAYER[newState] then
            local oldState = player.state
            player.state = States.PLAYER[newState]
            
            -- Add sound effects for state changes
            if newState == "ATTACK" and not params.suppressSound then
                AudioManager.playSound("playerAttack")
            elseif newState == "HIT" then
                AudioManager.playSound("playerHit")
            elseif newState == "DEATH" then
                AudioManager.playSound("playerDeath")
            end
            
            -- State actions
            if newState == "BLOCK" then
                player.block_type = params.blockType -- overhead, stab, or swing
                player.block_time = CONFIG.PLAYER.BLOCK_DURATION
            elseif newState == "ATTACK" then
                player.attack_time = CONFIG.PLAYER.ATTACK_DURATION
            elseif newState == "HIT" then
                player.hit_time = CONFIG.PLAYER.HIT_DURATION
            elseif newState == "DEATH" then
                player.death_time = love.timer.getTime()
            end
            
            Logger:log(Logger.INFO, string.format("Player state changed: %s -> %s", oldState, player.state))
        end
    end,
    
    updateState = function(dt)
        if player.state == States.PLAYER.BLOCK then
            -- Don't automatically end block state - it will be changed based on enemy attack result
            -- Only update the timer
            player.block_time = player.block_time - dt
        elseif player.state == States.PLAYER.ATTACK and player.attack_time > 0 then
            player.attack_time = player.attack_time - dt
            if player.attack_time <= 0 then
                StateManager.player.changeState("IDLE")
            end
        elseif player.state == States.PLAYER.HIT and player.hit_time > 0 then
            player.hit_time = player.hit_time - dt
            if player.hit_time <= 0 then
                if player.health <= 0 then
                    -- Transition to death after hit animation completes
                    StateManager.player.changeState("DEATH")
                else
                    StateManager.player.changeState("IDLE")
                    enemy.hit_delay = 0.5
                end
            end
        elseif player.state == States.PLAYER.DEATH then
            if love.timer.getTime() - player.death_time >= CONFIG.GAME.DEATH_TRANSITION_TIME then
                StateManager.game.changeState("GAMEOVER")
            end
        end
    end
}

StateManager.enemy = {
    changeState = function(newState, params)
        if States.ENEMY[newState] then
            local oldState = enemy.state
            enemy.state = States.ENEMY[newState]
            
            -- Add sound effects for state changes
            if newState == "HIT" then
                AudioManager.playSound("enemyHit")
            elseif newState == "DEATH" then
                AudioManager.playSound("enemyDeath")
            end
            
            -- State actions
            if newState == "INDICATOR" then
                blockStartTime = love.timer.getTime()
                enemy.attack_time = 0
            elseif newState == "ATTACK" then
                enemy.attack_time = 0
            elseif newState == "HIT" then
                enemy.hit_time = CONFIG.ENEMY.HIT_DURATION
            elseif newState == "DEATH" then
                enemy.death_time = CONFIG.ENEMY.DEATH_DURATION
            end
            
            if newState == "IDLE" then
                enemy.idle_time = CONFIG.ENEMY.IDLE_DURATION
            end
            
            Logger:log(Logger.INFO, string.format("Enemy state changed: %s -> %s", oldState, enemy.state))
        end
    end,
    
    updateState = function(dt)
        -- Add check for player death state at the start
        if player.state == States.PLAYER.DEATH then
            return  -- Don't update enemy if player is dead
        end

        if enemy.hit_delay > 0 then
            enemy.hit_delay = enemy.hit_delay - dt
            return
        end

        if enemy.state == States.ENEMY.IDLE then
            enemy.idle_time = enemy.idle_time - dt
            if enemy.idle_time <= 0 then
                local attackTypes = {"overhead", "stab", "swing"}
                enemy.attack = attackTypes[math.random(#attackTypes)]
                StateManager.enemy.changeState("INDICATOR")
                playerInputLocked = false
            end
        elseif enemy.state == States.ENEMY.INDICATOR then
            enemy.attack_time = enemy.attack_time + dt
            if enemy.attack_time >= enemy.indicator_time then
                StateManager.enemy.changeState("ATTACK")
            end
        elseif enemy.state == States.ENEMY.ATTACK then
            enemy.attack_time = enemy.attack_time + dt
            
            if enemy.attack_time >= 0 and not playerInputLocked then
                if player.state == States.PLAYER.BLOCK then
                    if player.block_type == enemy.attack then
                        -- Calculate reaction time only on successful block
                        local reactionTime = love.timer.getTime() - blockStartTime
                        totalBlockScore = totalBlockScore + reactionTime
                        Logger:log(Logger.INFO, string.format("Successful block! Reaction time: %.3f", reactionTime))
                        
                        -- Successful block
                        addTimer(0.5, function() -- Delay before counter-attack
                            -- Play attack sound and change player state first
                            AudioManager.playSound("playerAttack")
                            StateManager.player.changeState("ATTACK", {suppressSound = true}) -- Add parameter to prevent double sound
                            
                            -- Slight delay before enemy hit
                            addTimer(0.1, function()
                                StateManager.enemy.changeState("HIT")
                                enemy.health = math.max(0, enemy.health - player.damage)
                                
                                -- Reset both to idle after attack duration
                                addTimer(CONFIG.PLAYER.ATTACK_DURATION, function()
                                    enemy.attack = nil
                                    StateManager.player.changeState("IDLE")
                                end)
                            end)
                        end)
                    else
                        -- Wrong block type
                        player.health = math.max(0, player.health - enemy.damage)
                        StateManager.player.changeState("HIT")
                    end
                else
                    -- No block
                    player.health = math.max(0, player.health - enemy.damage)
                    StateManager.player.changeState("HIT")
                end
                playerInputLocked = true
            end
            
            -- End attack state
            if enemy.attack_time >= 1 then
                if enemy.state ~= States.ENEMY.HIT then  -- Changed != to ~=
                    StateManager.enemy.changeState("IDLE")
                    enemy.idle_time = 1
                    enemy.attack = nil
                end
                -- Only reset player to idle if they're still blocking
                if player.state == States.PLAYER.BLOCK then
                    StateManager.player.changeState("IDLE")
                end
            end
        elseif enemy.state == States.ENEMY.HIT then
            enemy.hit_time = enemy.hit_time - dt
            if enemy.hit_time <= 0 then
                if enemy.health <= 0 then
                    StateManager.enemy.changeState("DEATH")
                    StateManager.player.changeState("IDLE")
                else
                    StateManager.enemy.changeState("IDLE")
                    enemy.idle_time = 1
                end
            end
        elseif enemy.state == States.ENEMY.DEATH then
            enemy.death_time = enemy.death_time - dt
            if enemy.death_time <= 0 then
                score = score + 1
                
                -- Increase enemy health
                enemy.max_health = enemy.max_health + CONFIG.ENEMY.HEALTH_INCREASE_PER_LEVEL
                enemy.health = enemy.max_health
                
                -- Progressive damage increase
                local damageIncrease = CONFIG.ENEMY.DAMAGE_INCREASE_PER_LEVEL * math.floor(score / 3)
                enemy.damage = (CONFIG.ENEMY.INITIAL_DAMAGE * currentDifficulty.damageMultiplier) + damageIncrease
                
                -- Make attacks faster based on score
                -- More aggressive scaling for higher difficulties
                local speedScale = currentDifficulty.name == "Extreme" and 0.85 or 
                                  currentDifficulty.name == "Hard" and 0.9 or 0.95
                
                local minTime = currentDifficulty.name == "Extreme" and 0.2 or 
                               currentDifficulty.name == "Hard" and 0.4 or 0.5
                               
                enemy.indicator_time = math.max(
                    minTime,
                    currentDifficulty.indicatorTime * (speedScale ^ (score - 1))
                )
                
                StateManager.enemy.changeState("IDLE")
                enemy.idle_time = 1
                
                -- Log the progression
                Logger:log(Logger.INFO, string.format(
                    "Round %d - Enemy stats: Health: %d, Damage: %d, Speed: %.2f",
                    score, enemy.max_health, enemy.damage, enemy.indicator_time
                ))
            end
        end
    end
}

-- Update
function love.update(dt)
    -- Update timers
    updateTimers(dt)

    if gameState == States.GAME.PLAYING then
        StateManager.player.updateState(dt)
        StateManager.enemy.updateState(dt)
    elseif gameState == States.GAME.COUNTDOWN then
        countdown = countdown - dt
        if countdown <= 0 then
            StateManager.game.changeState("PLAYING")
        end
    end
end

-- Helper function to draw health bars
local function drawHealthBar(x, y, current, max, label, color)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, 30, 200 * (current / max), 20)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", x, 30, 200, 20)
    love.graphics.print(label .. ": " .. current .. "/" .. max, x, 55)
end

-- Menu drawing functions
local function drawMenu()
    if menuSprites.background then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(menuSprites.background, 0, 0)
    end

    local options = {"START", "How to Play", "EXIT"}
    love.graphics.setFont(fonts.large)
    for i, option in ipairs(options) do
        love.graphics.setColor(i == menuSelection and {1, 1, 1} or {0, 0, 0})
        love.graphics.printf(option, 0, 250 + (i - 1) * 100, CONFIG.WINDOW.WIDTH, "center")
    end
end

local function drawHowToPlay()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(menuSprites.background, 0, 0)
    
    love.graphics.setFont(fonts.medium)
    love.graphics.printf("How to Play", 0, 230, CONFIG.WINDOW.WIDTH, "center")
    
    love.graphics.setFont(fonts.small)
    local instructions = {
        "You need to block the enemy attacks via arrow keys (UP, DOWN, LEFT).",
        "The enemy can attack three different ways: OVERHEAD, STAB, OR SWING.",
        "If you're successful then you'll deal massive damage to the enemy.",
        "Press 'ESC' or 'M' to return to the main menu."
    }
    
    for i, text in ipairs(instructions) do
        love.graphics.printf(text, 50, 300 + (i - 1) * 50, 700, "center")
    end
end

local function drawCountdown()
    love.graphics.clear(0.533, 0, 0.082)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.medium)
    love.graphics.printf("Starting in.. " .. math.ceil(countdown), 0, 300, CONFIG.WINDOW.WIDTH, "center")
end

local function drawEnemySprite()
    if enemy.state == "death" then
        love.graphics.draw(enemySprites.death)
    elseif enemy.state == "indicator" and enemy.attack then
        love.graphics.draw(enemySprites[ATTACKS[enemy.attack].indicator])
    elseif enemy.state == "attack" and enemy.attack then
        love.graphics.draw(enemySprites[ATTACKS[enemy.attack].sprite])
    elseif enemy.state and enemySprites[enemy.state] then
        love.graphics.draw(enemySprites[enemy.state])
    end
end

local function drawPlayerSprite()
    if player.state == States.PLAYER.DEATH then
        love.graphics.draw(playerSprites.death)
    elseif player.state == States.PLAYER.BLOCK then
        love.graphics.draw(playerSprites["block" .. player.block_type:gsub("^%l", string.upper)])
    else
        love.graphics.draw(playerSprites[player.state])
    end
end

local highScoreFlashTimer = 0

-- Update drawGameOver
local function drawGameOver()
    love.graphics.clear(0.533, 0, 0.082)
    
    -- Game over text
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("GAME OVER", 0, 120, CONFIG.WINDOW.WIDTH, "center")
    
    -- Calculate scores
    love.graphics.setFont(fonts.medium)
    local enemyPoints = (score - 1) * difficultyPoints[currentDifficulty.name]
    local blockPoints = math.floor(totalBlockScore * difficultyMultipliers[currentDifficulty.name])
    local finalScore = enemyPoints + blockPoints
    
    -- Display enemies defeated and final score
    love.graphics.printf(string.format("Enemies Defeated: %d", score - 1), 0, 200, CONFIG.WINDOW.WIDTH, "center")
    love.graphics.printf(string.format("Final Score: %d", finalScore), 0, 250, CONFIG.WINDOW.WIDTH, "center")
    
    -- Show high score notification
    if finalScore > highScores[currentDifficulty.name] then
        
        highScoreFlashTimer = highScoreFlashTimer + love.timer.getDelta()
        
        
        local scale = 1 + math.sin(highScoreFlashTimer * 5) * 0.1
               
        love.graphics.setColor(1, 0.8, 0, 0.3)
        love.graphics.circle("fill", CONFIG.WINDOW.WIDTH / 2, 330, 150 * scale)
                
        love.graphics.setFont(fonts.large)
        love.graphics.setColor(1, 0.8, 0)  -- Gold color
        love.graphics.printf("NEW HIGH SCORE!", 0, 300, CONFIG.WINDOW.WIDTH, "center")
        
        love.graphics.setFont(fonts.small)
        love.graphics.printf(string.format("Previous Best: %d", highScores[currentDifficulty.name]), 0, 360, CONFIG.WINDOW.WIDTH, "center")
        love.graphics.printf(string.format("Improved by: +%d", finalScore - highScores[currentDifficulty.name]), 0, 380, CONFIG.WINDOW.WIDTH, "center")
        
        -- Update the high score
        highScores[currentDifficulty.name] = finalScore
        saveHighScores()
    else
        -- Show current high score
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(string.format("Best Score: %d", highScores[currentDifficulty.name]), 0, 300, CONFIG.WINDOW.WIDTH, "center")
        love.graphics.printf(string.format("Score needed: %d more", highScores[currentDifficulty.name] - finalScore), 0, 320, CONFIG.WINDOW.WIDTH, "center")
    end
    
    -- Menu options
    love.graphics.setFont(fonts.medium)
    local options = {"RESTART", "MENU", "EXIT"}
    for i, option in ipairs(options) do
        love.graphics.setColor(i == gameoverSelection and {1, 1, 1} or {0, 0, 0})
        love.graphics.printf(option, 0, 420 + (i - 1) * 50, CONFIG.WINDOW.WIDTH, "center")
    end
end

function love.draw()
    if gameState == "pause" then
        -- For pause state, don't clear the screen first
        drawPause()
    else
        -- For all other states, clear and draw normally
        love.graphics.clear(1, 1, 1)
        
        if gameState == "menu" then
            drawMenu()
        elseif gameState == "howToPlay" then
            drawHowToPlay()
        elseif gameState == "difficulty" then
            drawDifficulty()
        elseif gameState == "countdown" then
            drawCountdown()
        elseif gameState == "playing" then
            drawGameplay()
        elseif gameState == "gameover" then
            drawGameOver()
        end
    end
end

-- Key logic
function love.keypressed(key)
    if gameState == "menu" then
        if key == "up" then
            AudioManager.playSound("menuSelect")
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            AudioManager.playSound("menuSelect")
            menuSelection = math.min(3, menuSelection + 1)
        elseif key == "return" or key == "enter" then
            if menuSelection == 1 then
                gameState = "difficulty" -- Go to difficulty selection instead of starting game
            elseif menuSelection == 2 then
                gameState = "howToPlay"
            elseif menuSelection == 3 then
                love.event.quit()
            end
        end
    elseif gameState == "difficulty" then
        if key == "up" then
            AudioManager.playSound("menuSelect")
            difficultySelection = math.max(1, difficultySelection - 1)
        elseif key == "down" then
            AudioManager.playSound("menuSelect")
            difficultySelection = math.min(3, difficultySelection + 1)
        elseif key == "return" or key == "enter" then
            resetGameState() -- Start game with selected difficulty
        elseif key == "escape" then
            gameState = "menu"
            difficultySelection = 1 -- Reset selection when going back
        end
    elseif gameState == "gameover" then
        -- Navigate game over options
        if key == "up" then
            gameoverSelection = math.max(1, gameoverSelection - 1)
        elseif key == "down" then
            gameoverSelection = math.min(3, gameoverSelection + 1)
        elseif key == "return" or key == "enter" then
            if gameoverSelection == 1 then
                resetGameState() -- Restart the game
            elseif gameoverSelection == 2 then
                gameState = "menu" -- Return to menu
            elseif gameoverSelection == 3 then
                love.event.quit() -- Exit the game
            end
        end

    elseif gameState == "howToPlay" then
        if key == "escape" or key == "m" then
            gameState = "menu" -- Return to main menu
        end

    elseif gameState == "playing" then
        if key == "escape" or key == "return" then
            -- Take a screenshot of the current game state before pausing
            pauseScreenshot = love.graphics.newCanvas(CONFIG.WINDOW.WIDTH, CONFIG.WINDOW.HEIGHT)
            love.graphics.setCanvas(pauseScreenshot)
            drawGameplay()
            love.graphics.setCanvas()
            
            gameState = "pause"
            pauseSelection = 1
            return
        end
        
        if not playerInputLocked and enemy.attack and enemy.state == States.ENEMY.INDICATOR then
            local blockType = nil
            if key == "up" then
                blockType = "overhead"
            elseif key == "left" then
                blockType = "stab"
            elseif key == "down" then
                blockType = "swing"
            end

            if blockType then
                StateManager.player.changeState("BLOCK", {blockType = blockType})
            end
        end

    elseif gameState == "pause" then
        if key == "escape" then
            gameState = "playing"
            pauseScreenshot = nil  -- Clear the screenshot when unpausing
            return
        elseif key == "up" then
            AudioManager.playSound("menuSelect")
            pauseSelection = math.max(1, pauseSelection - 1)
        elseif key == "down" then
            AudioManager.playSound("menuSelect")
            pauseSelection = math.min(2, pauseSelection + 1)
        elseif key == "return" or key == "enter" then
            if pauseSelection == 1 then
                gameState = "playing"
                pauseScreenshot = nil  -- Clear the screenshot when unpausing
            else
                gameState = "menu"
                pauseScreenshot = nil  -- Clear the screenshot when exiting to menu
                AudioManager.playMusic("theme")
            end
        end
    end
end

-- Exit
function love.quit()
    AudioManager.stopMusic()
    -- print("Thanks for playing Warriors!")
end

function resetGameState()
    local success, err = pcall(function()
        gameState = "countdown"
        countdown = CONFIG.GAME.COUNTDOWN_TIME
        
        if difficultySelection == 1 then
            currentDifficulty = DIFFICULTIES.NORMAL
        elseif difficultySelection == 2 then
            currentDifficulty = DIFFICULTIES.HARD
        else
            currentDifficulty = DIFFICULTIES.EXTREME
        end
        
        -- Log the selected difficulty
        Logger:log(Logger.INFO, "Selected difficulty: " .. currentDifficulty.name)
        
        -- Reset player with difficulty settings
        player.health = currentDifficulty.playerHealth
        player.state = "idle"
        player.hit_time = 0
        player.attack_time = 0
        player.death_time = 0
        
        -- Reset enemy with difficulty settings
        enemy.health = CONFIG.ENEMY.INITIAL_HEALTH
        enemy.max_health = CONFIG.ENEMY.INITIAL_HEALTH
        enemy.damage = CONFIG.ENEMY.INITIAL_DAMAGE * currentDifficulty.damageMultiplier
        enemy.indicator_time = currentDifficulty.indicatorTime
        enemy.state = "idle"
        enemy.attack = nil
        enemy.attack_time = 0
        enemy.hit_time = 0
        enemy.idle_time = 1
        enemy.death_time = 0
        enemy.hit_delay = 0
        
        -- Reset game
        score = 1
        playerInputLocked = false
        
        -- Reset scoring
        blockStartTime = 0
        totalBlockScore = 0
        
        highScoreFlashTimer = 0
        
        Logger:log(Logger.INFO, "Game state reset successfully with difficulty: " .. currentDifficulty.name)
    end)
    
    if not success then
        Logger:log(Logger.ERROR, "Failed to reset game state: " .. tostring(err))
        gameState = "menu"
    end
end

local function drawGameplay()
    -- Draw background
    if background then
        love.graphics.draw(background, 0, 0)
    end

    -- Display round
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("ROUND: " .. score, 0, 10, CONFIG.WINDOW.WIDTH, "center")

    -- Health bars
    love.graphics.setFont(fonts.small)
    drawHealthBar(30, 30, player.health, currentDifficulty.playerHealth, "Player HP", {0, 1, 0})
    drawHealthBar(570, 30, enemy.health, enemy.max_health, "Enemy HP", {1, 0, 0})

    -- Draw characters
    love.graphics.setColor(1, 1, 1)
    drawEnemySprite()
    drawPlayerSprite()
end

-- Add drawing function for difficulty screen
local function drawDifficulty()
    love.graphics.clear(0.533, 0, 0.082)
    
    -- Title
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("Select Difficulty", 0, 80, CONFIG.WINDOW.WIDTH, "center")
    
    -- Difficulty options and descriptions
    love.graphics.setFont(fonts.medium)
    local options = {
        {
            name = "Normal",
            desc = "Standard experience",
            stats = "Health: 100  |  Enemy Damage: Normal  |  Attack Speed: Normal"
        },
        {
            name = "Hard",
            desc = "For skilled warriors",
            stats = "Health: 100  |  Enemy Damage: Double  |  Attack Speed: Fast"
        },
        {
            name = "Extreme",
            desc = "True warrior's challenge",
            stats = "Health: 1  |  Enemy Damage: Lethal  |  Attack Speed: Very Fast"
        }
    }
    
    for i, option in ipairs(options) do

        love.graphics.setFont(fonts.medium)
        love.graphics.setColor(i == difficultySelection and {1, 1, 1} or {0, 0, 0})
        love.graphics.printf(option.name, 0, 200 + (i - 1) * 120, CONFIG.WINDOW.WIDTH, "center")
        
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(i == difficultySelection and {0.8, 0.8, 0.8} or {0.3, 0.3, 0.3})
        love.graphics.printf(option.desc, 0, 240 + (i - 1) * 120, CONFIG.WINDOW.WIDTH, "center")
        
        love.graphics.printf(option.stats, 0, 260 + (i - 1) * 120, CONFIG.WINDOW.WIDTH, "center")
    end
    
    -- Instructions
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("Press ENTER to select, ESC to go back", 0, 550, CONFIG.WINDOW.WIDTH, "center")
end


local function drawPause()
    -- Draw the cached gameplay screenshot
    if pauseScreenshot then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(pauseScreenshot, 0, 0)
    end
    
    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, CONFIG.WINDOW.WIDTH, CONFIG.WINDOW.HEIGHT)
    
    -- Draw pause menu
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, 150, CONFIG.WINDOW.WIDTH, "center")
    
    -- Menu options
    local options = {"RESUME", "EXIT TO MENU"}
    love.graphics.setFont(fonts.medium)
    for i, option in ipairs(options) do
        love.graphics.setColor(i == pauseSelection and {1, 1, 1} or {0.5, 0.5, 0.5})
        love.graphics.printf(option, 0, 300 + (i - 1) * 80, CONFIG.WINDOW.WIDTH, "center")
    end
end
