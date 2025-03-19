local player = {health = 100, damage = 50, state = "idle", hit_time = 0, attack_time = 0, block_time = 0, death_time = 0}
local enemy = {health = 100, max_health = 100, damage = 10, state = "idle", attack = nil, attack_time = 0, indicator_time = 1.5, hit_time = 0, idle_time = 0, death_time = 0, hit_delay = 0}
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

-- Loading
function love.load()
    -- SET FIXED WINDOW + TITLE
    love.window.setMode(800, 600)
    love.window.setTitle("Warriors")

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

-- Update
function love.update(dt)
    if gameState == "menu" then
        -- Wait for user to select an option
    elseif gameState == "howToPlay" then
        -- Wait for input to return to the menu
    elseif gameState == "countdown" then
        countdown = countdown - dt
        if countdown <= 0 then
            gameState = "playing"
        end
    elseif gameState == "playing" then

        -- PLAYER ATTACK
        if player.state == "attack" and player.attack_time > 0 then
            player.attack_time = player.attack_time - dt
            if player.attack_time <= 0 then
                player.state = "idle" -- Reset to idle after attacking
            end
        end

        -- PLAYER HIT
        if player.state == "hit" and player.hit_time > 0 then
            player.hit_time = player.hit_time - dt
            if player.hit_time <= 0 then
                player.state = "idle" -- Reset player to idle after hit
                enemy.hit_delay = 0.5 -- Add delay before enemy continues
            end
        end

        if player.state == "death" then
            if love.timer.getTime() - player.death_time >= 2 then
                gameState = "gameover"
            end
        end

        -- ENEMY LOGIC
        if enemy.hit_delay > 0 then
            enemy.hit_delay = enemy.hit_delay - dt
            
        elseif enemy.state == "idle" then
            enemy.idle_time = enemy.idle_time - dt
            if enemy.idle_time <= 0 then
                -- Begin a new attack cycle
                local attackTypes = {"overhead", "stab", "swing"}
                enemy.attack = attackTypes[math.random(#attackTypes)]
                enemy.state = "indicator"
                enemy.attack_time = 0
                playerInputLocked = false -- Allow new input
            end

        elseif enemy.state == "indicator" then
            enemy.attack_time = enemy.attack_time + dt
            if enemy.attack_time >= enemy.indicator_time then
                -- Transition to attack if no input was received
                enemy.state = "attack"
                enemy.attack_time = 0
            end

        elseif enemy.state == "attack" then
            enemy.attack_time = enemy.attack_time + dt

            -- Check counter and render check >= 0 instead of == 0 for potential missed frames
            if enemy.attack_time >= 0 and not playerInputLocked then
                player.health = math.max(0, player.health - enemy.damage)
                player.state = "hit"
                player.hit_time = 1
                playerInputLocked = true
            end

            if enemy.attack_time >= 1 then
                enemy.state = "idle"
                enemy.idle_time = 1
                enemy.attack = nil
                enemy.attack_time = 0
            end

        elseif enemy.state == "hit" then
            enemy.hit_time = enemy.hit_time - dt
            if enemy.hit_time <= 0 then
                -- Enemy dies if health reaches zero
                if enemy.health <= 0 then
                    enemy.state = "death"
                    enemy.death_time = 1 -- Stay in "death" state for 1 second
                    player.state = "idle" -- Reset player state after kill
                else
                    -- Return to idle after hit
                    enemy.state = "idle"
                    enemy.idle_time = 1
                end
            end

        elseif enemy.state == "death" then
            enemy.death_time = enemy.death_time - dt
            if enemy.death_time <= 0 then
                -- Spawn a new enemy
                score = score + 1 -- Increment round
                enemy.max_health = enemy.max_health + 20 -- Enemy gains 20 HP each time
                enemy.health = enemy.max_health
                enemy.damage = enemy.damage + 5 -- Enemy gains 5 damage each time
                enemy.indicator_time = math.max(0.5, enemy.indicator_time * 0.9) -- Ramp up speed by 10%
                enemy.state = "idle"
                enemy.idle_time = 1 -- Pause before next attack
            end
        end

        -- Check player health
        if player.health <= 0 and player.state ~= "death" then
            player.state = "death"
            player.death_time = love.timer.getTime()
        end
    end
end

-- Drawing
function love.draw()
    love.graphics.clear(1,1,1)

    if gameState == "menu" then
        -- Render the main menu
        if menuSprites.background then
            love.graphics.setColor(1,1,1)
            love.graphics.draw(menuSprites.background, 0, 0)
        end

        -- Menu options
        local options = {"START", "How to Play", "EXIT"}
        love.graphics.setFont(fonts.large)
        for i, option in ipairs(options) do
            if i == menuSelection then
                love.graphics.setColor(1, 1, 1) -- Highlighted option
            else
                love.graphics.setColor(0, 0, 0) -- Normal option
            end
            love.graphics.printf(option, 0, 250 + (i - 1) * 100, 800, "center")
        end

    elseif gameState == "howToPlay" then
        -- How to Play screen
        love.graphics.setColor(1,1,1)
        love.graphics.draw(menuSprites.background, 0, 0)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("How to Play", 0, 230, 800, "center")
        love.graphics.setFont(fonts.small)
        love.graphics.printf("You need to block the enemy attacks via arrow keys (UP, DOWN, LEFT).", 50, 300, 700, "center")
        love.graphics.printf("The enemy can attack three different ways: OVERHEAD, STAB, OR SWING.", 50, 350, 700, "center")
        love.graphics.printf("If you're successful then you'll deal massive damage to the enemy.", 50, 400, 700, "center")
        love.graphics.printf("Press 'ESC' or 'M' to return to the main menu.", 50, 500, 700, "center")

    elseif gameState == "countdown" then
        -- Countdown for starts
        love.graphics.clear(0.533, 0, 0.082) -- Background color copy
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Starting in.. " .. math.ceil(countdown), 0, 300, 800, "center")

    elseif gameState == "playing" then
        -- Draw background
        if background then
            love.graphics.draw(background, 0, 0)
        end

        -- Render the playing state
        -- love.graphics.clear(1, 1, 1)
        love.graphics.setColor(0, 0, 0)

        -- Ensure correct font size
        love.graphics.setFont(fonts.small)

        -- Display the current round
        love.graphics.setFont(fonts.medium)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("ROUND: " .. score, 0, 10, 800, "center")

        -- Reset font
        love.graphics.setFont(fonts.small)

        -- Player health bar
        love.graphics.setColor(0, 1, 0) -- Green for health bar
        love.graphics.rectangle("fill", 30, 30, 200 * (player.health / 100), 20)
        love.graphics.setColor(0, 0, 0) -- Black outline
        love.graphics.rectangle("line", 30, 30, 200, 20)
        love.graphics.print("Player HP: " .. player.health .. "/100", 30, 55)

        -- Enemy health bar
        love.graphics.setColor(1, 0, 0) -- Red for health bar
        love.graphics.rectangle("fill", 570, 30, 200 * (enemy.health / enemy.max_health), 20)
        love.graphics.setColor(0, 0, 0) -- Black outline
        love.graphics.rectangle("line", 570, 30, 200, 20)
        love.graphics.print("Enemy HP: " .. enemy.health .. "/" .. enemy.max_health, 570, 55)

        -- Reset to white background before rendering sprites (sprite colors clash)
        love.graphics.setColor(1, 1, 1)

        -- Draw enemy sprite
        if enemy.state == "death" then
            love.graphics.draw(enemySprites.death)

        elseif enemy.state == "indicator" then
            if enemy.attack == "overhead" then
                love.graphics.draw(enemySprites.indicatorOverhead, enemy.x, enemy.y)
            elseif enemy.attack == "stab" then
                love.graphics.draw(enemySprites.indicatorStab, enemy.x, enemy.y)
            elseif enemy.attack == "swing" then
                love.graphics.draw(enemySprites.indicatorSwing, enemy.x, enemy.y)
            end

        elseif enemy.state == "attack" then
            if enemy.attack == "overhead" then
                love.graphics.draw(enemySprites.attackOverhead, enemy.x, enemy.y)
            elseif enemy.attack == "stab" then
                love.graphics.draw(enemySprites.attackStab, enemy.x, enemy.y)
            elseif enemy.attack == "swing" then
                love.graphics.draw(enemySprites.attackSwing, enemy.x, enemy.y)
            end

        elseif enemy.state and enemySprites[enemy.state] then
            love.graphics.draw(enemySprites[enemy.state], enemy.x, enemy.y)
        end

        -- Draw player sprite
        if player.state == "death" then
            love.graphics.draw(playerSprites.death)
        else
            love.graphics.draw(playerSprites[player.state])
        end

    elseif gameState == "gameover" then
        -- Render the game over screen
        love.graphics.setFont(fonts.medium)
        love.graphics.clear(0.533, 0, 0.082) -- Background color copy
        love.graphics.setColor(0, 0, 0) -- Black text
        love.graphics.printf("GAME OVER", 0, 100, 800, "center")
        love.graphics.printf("Enemies Defeated: " .. (score - 1), 0, 200, 800, "center")
        -- Game over menu options
        local options = {"RESTART", "MENU", "EXIT"}

        for i, option in ipairs(options) do
            if i == gameoverSelection then
                love.graphics.setColor(1, 1, 1) -- Highlighted option
            else
                love.graphics.setColor(0, 0, 0) -- Normal option
            end
            love.graphics.printf(option, 0, 330 + (i - 1) * 50, 800, "center")
        end
    end
end

-- Game state reset
function resetGameState()
    gameState = "countdown"
    countdown = 2
    player.health = 100
    player.state = "idle"
    player.hit_time = 0
    player.attack_time = 0
    player.death_time = 0
    enemy.health = 100
    enemy.max_health = 100
    enemy.damage = 20
    enemy.indicator_time = 0.5
    enemy.state = "idle"
    enemy.attack = nil
    enemy.attack_time = 0
    enemy.hit_time = 0
    enemy.idle_time = 1
    enemy.death_time = 0
    enemy.hit_delay = 0
    score = 1
    playerInputLocked = false
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
        -- Handle counter input during gameplay
        if enemy.attack and key == counterKey[enemy.attack] then
            -- Successful counter
            enemy.health = math.max(0, enemy.health - player.damage) -- Reduce enemy health
            player.state = "attack"
            player.attack_time = 0.5 -- Player stays in attack state for 0.5 seconds
            enemy.state = "hit"
            enemy.hit_time = 1 -- Enemy stays in hit state for 1 second
            enemy.attack = nil -- Clear the enemy's current attack
            playerInputLocked = true -- Lock player input for the current cycle

        elseif enemy.attack then
            -- Failed counter
            player.health = math.max(0, player.health - enemy.damage) -- Reduce player health
            player.state = "hit"
            player.hit_time = 1 -- Player stays in hit state for 1 second
            enemy.state = "idle" -- Enemy returns to idle state
            enemy.idle_time = 1 -- Pause before the next attack
            enemy.attack = nil -- Clear the enemy's attack
            playerInputLocked = true
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
