-- Load Love2D libraries
local player = {x = 150, y = 200, health = 100, damage = 50, state = "idle", hit_time = 0, attack_time = 0}
local enemy = {x = 350, y = 200, health = 100, max_health = 100, damage = 10, state = "idle", attack = nil, attack_time = 0, indicator_time = 1.5, hit_time = 0, idle_time = 0, death_time = 0, hit_delay = 0}
local gameState = "menu"
local countdown = 2
local counterKey = {overhead = "up", stab = "left", swing = "down"}
local score = 1 -- Score tracker (represents the current round)
local playerInputLocked = false -- Prevent multiple inputs during a single attack cycle
local menuSelection = 1 -- Menu navigation index
local playerSprites = {}
local enemySprites = {}

-- Helper function for safe image loading
function safeLoadImage(path)
    local success, image = pcall(love.graphics.newImage, path)
    if success then
        return image
    else
        print("Error loading image: " .. path)
        return nil
    end
end

-- Love2D Functions
function love.load()
    -- Set fixed window size and title
    love.window.setMode(800, 600)
    love.window.setTitle("Warriors")

    -- Load player sprites
    playerSprites.idle = safeLoadImage("assets/player_idle.png")
    playerSprites.hit = safeLoadImage("assets/player_hit.png")
    playerSprites.attack = safeLoadImage("assets/player_attack.png")

    -- Load enemy sprites
    enemySprites.idle = safeLoadImage("assets/enemy_idle.png")
    enemySprites.hit = safeLoadImage("assets/enemy_hit.png")
    enemySprites.death = safeLoadImage("assets/enemy_death.png")
    enemySprites.attackOverhead = safeLoadImage("assets/enemy_attack_overhead.png")
    enemySprites.attackStab = safeLoadImage("assets/enemy_attack_stab.png")
    enemySprites.attackSwing = safeLoadImage("assets/enemy_attack_swing.png")
    enemySprites.indicatorOverhead = safeLoadImage("assets/enemy_indicator_overhead.png")
    enemySprites.indicatorStab = safeLoadImage("assets/enemy_indicator_stab.png")
    enemySprites.indicatorSwing = safeLoadImage("assets/enemy_indicator_swing.png")
end

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
        -- Player "attack" state handling
        if player.state == "attack" and player.attack_time > 0 then
            player.attack_time = player.attack_time - dt
            if player.attack_time <= 0 then
                player.state = "idle" -- Reset to idle after attacking
            end
        end

        -- Player "hit" state handling
        if player.state == "hit" and player.hit_time > 0 then
            player.hit_time = player.hit_time - dt
            if player.hit_time <= 0 then
                player.state = "idle" -- Reset player to idle after hit
                enemy.hit_delay = 0.5 -- Add delay before enemy continues
            end
        end

        -- Handle enemy logic
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
            if enemy.attack_time >= 1 then
                -- Player fails to counter
                player.health = math.max(0, player.health - enemy.damage)
                player.state = "hit"
                player.hit_time = 1 -- Stay in hit state for 1 second
                enemy.state = "idle"
                enemy.idle_time = 1 -- Pause before next attack
                enemy.attack = nil
                playerInputLocked = true -- Prevent input until next attack
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
        if player.health <= 0 then
            gameState = "gameover"
        end
    end
end

function love.draw()
    if gameState == "menu" then
        -- Render the main menu
        love.graphics.clear(1, 1, 1) -- White background
        love.graphics.setColor(0, 0, 0) -- Black text
        love.graphics.printf("WARRIORS", 0, 100, 800, "center") -- Title

        -- Menu options
        local options = {"Start Game", "How to Play"}
        for i, option in ipairs(options) do
            if i == menuSelection then
                love.graphics.setColor(0.2, 0.2, 0.8) -- Highlighted option
            else
                love.graphics.setColor(0, 0, 0) -- Normal option
            end
            love.graphics.printf(option, 0, 200 + (i - 1) * 40, 800, "center")
        end

    elseif gameState == "howToPlay" then
        -- Render the How to Play screen
        love.graphics.clear(1, 1, 1) -- White background
        love.graphics.setColor(0, 0, 0) -- Black text
        love.graphics.printf("HOW TO PLAY", 0, 100, 800, "center")
        love.graphics.printf("Press the arrow keys (UP, LEFT, DOWN) to block enemy attacks.", 50, 200, 700, "center")
        love.graphics.printf("Press ESC or M to return to the main menu.", 50, 300, 700, "center")

    elseif gameState == "countdown" then
        -- Render the countdown before the game starts
        love.graphics.clear(1, 1, 1) -- White background
        love.graphics.setColor(0, 0, 0) -- Black text
        love.graphics.printf("Get ready! " .. math.ceil(countdown), 0, 300, 800, "center")

    elseif gameState == "playing" then
        -- Render the playing state
        love.graphics.clear(1, 1, 1) -- White background
        love.graphics.setColor(0, 0, 0) -- Black text

        -- Display the current round
        love.graphics.printf("ROUND: " .. score, 0, 10, 800, "center")

        -- Player health bar
        love.graphics.setColor(0, 1, 0) -- Green for health bar
        love.graphics.rectangle("fill", 10, 30, 200 * (player.health / 100), 20)
        love.graphics.setColor(0, 0, 0) -- Black outline
        love.graphics.rectangle("line", 10, 30, 200, 20)
        love.graphics.print("Player HP: " .. player.health .. "/100", 10, 55)

        -- Enemy health bar
        love.graphics.setColor(1, 0, 0) -- Red for health bar
        love.graphics.rectangle("fill", 590, 30, 200 * (enemy.health / enemy.max_health), 20)
        love.graphics.setColor(0, 0, 0) -- Black outline
        love.graphics.rectangle("line", 590, 30, 200, 20)
        love.graphics.print("Enemy HP: " .. enemy.health .. "/" .. enemy.max_health, 590, 55)

        -- Reset to white before rendering sprites
        love.graphics.setColor(1, 1, 1)

        -- Draw player sprite
        if playerSprites[player.state] then
            love.graphics.draw(playerSprites[player.state], player.x, player.y)
        end

        -- Draw enemy sprite
        if enemy.state == "death" then
            love.graphics.draw(enemySprites.death, enemy.x, enemy.y)
        elseif enemy.state and enemySprites[enemy.state] then
            love.graphics.draw(enemySprites[enemy.state], enemy.x, enemy.y)
        elseif enemy.attack then
            love.graphics.draw(enemySprites["attack" .. enemy.attack:sub(1, 1):upper() .. enemy.attack:sub(2)], enemy.x, enemy.y)
        end

    elseif gameState == "gameover" then
        -- Render the game over screen
        love.graphics.clear(1, 1, 1) -- White background
        love.graphics.setColor(0, 0, 0) -- Black text
        love.graphics.printf("GAME OVER", 0, 100, 800, "center")
        love.graphics.printf("Enemies Defeated: " .. (score - 1), 0, 200, 800, "center")
        love.graphics.printf("Press R to restart, M to return to the menu, or X to exit.", 50, 400, 700, "center")
    end
end

-- Function to reset the game state for a new round or restart
function resetGameState()
    gameState = "countdown"
    countdown = 2
    player.health = 100
    player.state = "idle"
    player.hit_time = 0
    player.attack_time = 0
    enemy.health = 100
    enemy.max_health = 100
    enemy.damage = 10
    enemy.indicator_time = 1.5
    enemy.state = "idle"
    enemy.attack = nil
    enemy.attack_time = 0
    enemy.hit_time = 0
    enemy.idle_time = 0
    enemy.death_time = 0
    enemy.hit_delay = 0
    score = 1
    playerInputLocked = false
end

-- Key pressed logic
function love.keypressed(key)
    if gameState == "menu" then
        -- Navigate menu options
        if key == "up" then
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            menuSelection = math.min(2, menuSelection + 1)
        elseif key == "return" or key == "enter" then
            if menuSelection == 1 then
                resetGameState() -- Start the game
            elseif menuSelection == 2 then
                gameState = "howToPlay" -- Show the How to Play screen
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

-- Love2D Quit event for exiting
function love.quit()
    print("Thanks for playing Warriors!")
end
