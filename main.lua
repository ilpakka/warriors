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
local playerInputLocked = false -- Prevent multiple inputs during a single attack cycle
local menuSelection = 1 -- Menu navigation index
local gameoverSelection = 1 -- Game over menu navigation index
local playerSprites = {}
local enemySprites = {}
local menuSprites = {}
local fonts = {}
local background

-- Game Configuration
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
        COUNTDOWN = "countdown",
        PLAYING = "playing",
        GAMEOVER = "gameover"
    }
}

-- Forward declare StateManager
local StateManager = {}

-- Define StateManager components
StateManager.game = {
    changeState = function(newState)
        if States.GAME[newState] then
            local oldState = gameState
            gameState = States.GAME[newState]
            Logger:log(Logger.INFO, string.format("Game state changed: %s -> %s", oldState, gameState))
        end
    end
}

StateManager.player = {
    changeState = function(newState, params)
        if States.PLAYER[newState] then
            local oldState = player.state
            player.state = States.PLAYER[newState]
            
            -- State entry actions
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
                StateManager.player.changeState("IDLE")
                enemy.hit_delay = 0.5
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
            
            -- State entry actions
            if newState == "INDICATOR" then
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
            
            -- Check block success at the start of attack animation
            if enemy.attack_time >= 0 and not playerInputLocked then
                if player.state == States.PLAYER.BLOCK then
                    if player.block_type == enemy.attack then
                        -- Successful block
                        addTimer(0.5, function() -- Delay before counter-attack
                            -- Change both states simultaneously
                            StateManager.player.changeState("ATTACK")
                            StateManager.enemy.changeState("HIT")
                            enemy.health = math.max(0, enemy.health - player.damage)
                            
                            -- Reset both to idle after attack duration
                            addTimer(CONFIG.PLAYER.ATTACK_DURATION, function()
                                enemy.attack = nil
                                StateManager.player.changeState("IDLE")
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
                enemy.max_health = enemy.max_health + CONFIG.ENEMY.HEALTH_INCREASE_PER_LEVEL
                enemy.health = enemy.max_health
                enemy.damage = enemy.damage + CONFIG.ENEMY.DAMAGE_INCREASE_PER_LEVEL
                enemy.indicator_time = math.max(
                    CONFIG.ENEMY.MIN_INDICATOR_TIME,
                    enemy.indicator_time * CONFIG.ENEMY.SPEED_INCREASE_FACTOR
                )
                StateManager.enemy.changeState("IDLE")
                enemy.idle_time = 1
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
        
        -- Check player health
        if player.health <= 0 and player.state ~= States.PLAYER.DEATH then
            StateManager.player.changeState("DEATH")
        end
    elseif gameState == States.GAME.COUNTDOWN then
        countdown = countdown - dt
        if countdown <= 0 then
            StateManager.game.changeState("PLAYING")
        end
    end
end

-- Add these drawing helper functions before love.draw

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
    drawHealthBar(30, 30, player.health, CONFIG.PLAYER.INITIAL_HEALTH, "Player HP", {0, 1, 0})
    drawHealthBar(570, 30, enemy.health, enemy.max_health, "Enemy HP", {1, 0, 0})

    -- Draw characters
    love.graphics.setColor(1, 1, 1)
    drawEnemySprite()
    drawPlayerSprite()
end

local function drawGameOver()
    love.graphics.clear(0.533, 0, 0.082)
    love.graphics.setFont(fonts.medium)
    
    -- Game over text
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("GAME OVER", 0, 100, CONFIG.WINDOW.WIDTH, "center")
    love.graphics.printf("Enemies Defeated: " .. (score - 1), 0, 200, CONFIG.WINDOW.WIDTH, "center")
    
    -- Menu options
    local options = {"RESTART", "MENU", "EXIT"}
    for i, option in ipairs(options) do
        love.graphics.setColor(i == gameoverSelection and {1, 1, 1} or {0, 0, 0})
        love.graphics.printf(option, 0, 330 + (i - 1) * 50, CONFIG.WINDOW.WIDTH, "center")
    end
end

-- Update the main draw function to use these components
function love.draw()
    love.graphics.clear(1, 1, 1)

    if gameState == "menu" then
        drawMenu()
    elseif gameState == "howToPlay" then
        drawHowToPlay()
    elseif gameState == "countdown" then
        drawCountdown()
    elseif gameState == "playing" then
        drawGameplay()
    elseif gameState == "gameover" then
        drawGameOver()
    end
end

-- Game state reset
function resetGameState()
    local success, err = pcall(function()
        gameState = "countdown"
        countdown = CONFIG.GAME.COUNTDOWN_TIME
        
        -- Reset player
        player.health = CONFIG.PLAYER.INITIAL_HEALTH
        player.state = "idle"
        player.hit_time = 0
        player.attack_time = 0
        player.death_time = 0
        
        -- Reset enemy
        enemy.health = CONFIG.ENEMY.INITIAL_HEALTH
        enemy.max_health = CONFIG.ENEMY.INITIAL_HEALTH
        enemy.damage = CONFIG.ENEMY.INITIAL_DAMAGE
        enemy.indicator_time = CONFIG.ENEMY.INDICATOR_TIME
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
        
        Logger.log(Logger.INFO, "Game state reset successfully")
    end)
    
    if not success then
        Logger.log(Logger.ERROR, "Failed to reset game state: " .. tostring(err))
        -- Fallback to menu state if reset fails
        gameState = "menu"
    end
end

-- Key logic
function love.keypressed(key)
    if gameState == "menu" then
        -- Navigate menu options
        if key == "up" then
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            menuSelection = math.min(3, menuSelection + 1)
        elseif key == "return" or key == "enter" then
            if menuSelection == 1 then
                resetGameState() -- Start the game
            elseif menuSelection == 2 then
                gameState = "howToPlay" -- Show the How to Play screen
            elseif menuSelection == 3 then
                love.event.quit() -- Exit the game
            end
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

    elseif gameState == "playing" and not playerInputLocked then
        if enemy.attack and enemy.state == States.ENEMY.INDICATOR then
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

    elseif gameState == "gameover" then
        -- Handle Game Over options
        if key == "x" then
            love.event.quit() -- Exit the game
        elseif key == "m" or key == "return" then
            gameState = "menu" -- Return to main menu
        elseif key == "r" then
            resetGameState() -- Restart the game
        end
    end
end

-- Exit
function love.quit()
    -- print("Thanks for playing Warriors!")
end
