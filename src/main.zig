const rl = @import("raylib");
const std = @import("std");
const m = @import("math");

const Vector2 = rl.Vector2;

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 450;
const WHITE = rl.Color.white;
const ACCENTCOLOR = rl.Color.green;
const LINE_THICKNESS = 10;
const LINE_THICKNESS_FLOAT: f32 = @floatFromInt(LINE_THICKNESS);
const BALL_GRAVITY_CONSTANT = 7;
const BALL_RADIUS = 11;
const PLAYER_HEIGHT = 80;
const PLAYER_WIDTH = 60;
const PLAYER_WIDTH_THROUGH_THREE: i32 = @intFromFloat(PLAYER_WIDTH_THROUGH_THREE_FLOAT);
const PLAYER_WIDTH_THROUGH_THREE_FLOAT: f32 = PLAYER_WIDTH / 3;
const NET_HEIGHT = 0.35;

// Game State
var gameIsRunning: bool = false;
var deathScreen: bool = false;
var frameCount: i32 = 0;
var pauseSince: f64 = 0;
var shootBallLeft = false;
var lastBeepedNumber: f64 = 4;
var showFPS: bool = true;
var reverseJump: bool = false;
var ballHadCollisionLastFrame: bool = false;
var ballHasCollisionThisFrame: bool = false;

// Player
// Position
var player1X: f64 = 0;
var player1Y: f64 = 0;
var player2X: f64 = 0;
var player2Y: f64 = 0;
// Movement
var player1MY: f64 = 0;
var player2MY: f64 = 0;
// Score
pub var player1Score: i8 = 7;
pub var player2Score: i8 = 3;

// Ball
// Position
var ballX: f64 = 0;
var ballY: f64 = 0;
// Movement
var ballMX: f64 = 0;
var ballMY: f64 = 0;
// Collision
var stayOverHight: f64 = WINDOW_HEIGHT;
var stayLeftFrom: f64 = WINDOW_WIDTH;
var stayRightFrom: f64 = 0;

// Sound
const Sound = struct {
    borderCollision: rl.Sound,
    playerCollision: rl.Sound,
    victory: rl.Sound,
    countdown: rl.Sound,
    countdownEnd: rl.Sound,
    floor: rl.Sound,
};
var sound: Sound = undefined;

pub fn main() anyerror!void {

    // Init
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Volleyball Arcade");
    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(60);
    rl.initAudioDevice();

    sound = .{
        .borderCollision = rl.loadSound("resources/wall_collision.wav"),
        .playerCollision = rl.loadSound("resources/player_collision.mp3"),
        .victory = rl.loadSound("resources/victory.mp3"),
        .countdown = rl.loadSound("resources/count_down.mp3"),
        .countdownEnd = rl.loadSound("resources/count_down_end.wav"),
        .floor = rl.loadSound("resources/floor_collision.mp3"),
    };

    // Main game loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        if (gameIsRunning) {
            const pause = rl.getTime() - pauseSince;
            if (pause >= 4) {
                if (lastBeepedNumber == 0) {
                    lastBeepedNumber = 4;
                    rl.playSound(sound.countdownEnd);
                }

                stayOverHight = WINDOW_HEIGHT;
                stayLeftFrom = WINDOW_WIDTH;
                stayRightFrom = 0;

                // Compute all changes in public variables
                ballMY += rl.getFrameTime() * BALL_GRAVITY_CONSTANT;

                const newBallX: f64 = ballX + ballMX;
                const newBallY: f64 = ballY + ballMY;

                // Player 1
                if (rl.isKeyDown(.a)) {
                    player1X -= rl.getFrameTime() * 300;
                    player1X = @max(LINE_THICKNESS + PLAYER_WIDTH / 2, player1X);
                } else if (rl.isKeyDown(.d)) {
                    player1X += rl.getFrameTime() * 300;
                    player1X = @min((WINDOW_WIDTH - LINE_THICKNESS - PLAYER_WIDTH) / 2, player1X);
                }

                // Player 1 Jump
                if ((rl.isKeyDown(.w) and player1Y == 0 and !reverseJump) or (reverseJump and rl.isKeyDown(.i) and player1Y == 0)) {
                    player1MY = 2;
                    player1Y += BALL_GRAVITY_CONSTANT * player1MY;
                } else if (player1Y != 0) {
                    player1MY -= rl.getFrameTime() * BALL_GRAVITY_CONSTANT;
                    player1Y += BALL_GRAVITY_CONSTANT * player1MY;
                    player1Y = @max(0, player1Y);
                } else {
                    player1MY = 0;
                }

                // Player 2
                if (rl.isKeyDown(.j)) {
                    player2X -= rl.getFrameTime() * 300;
                    player2X = @max((WINDOW_WIDTH + LINE_THICKNESS + PLAYER_WIDTH) / 2, player2X);
                } else if (rl.isKeyDown(.l)) {
                    player2X += rl.getFrameTime() * 300;
                    player2X = @min(WINDOW_WIDTH - LINE_THICKNESS - PLAYER_WIDTH / 2, player2X);
                }

                // Player 2 Jump
                if ((rl.isKeyDown(.i) and player2Y == 0 and !reverseJump) or (reverseJump and rl.isKeyDown(.w) and player2Y == 0)) {
                    player2MY = 2;
                    player2Y += BALL_GRAVITY_CONSTANT * player2MY;
                } else if (player2Y != 0) {
                    player2MY -= rl.getFrameTime() * BALL_GRAVITY_CONSTANT;
                    player2Y += BALL_GRAVITY_CONSTANT * player2MY;
                    player2Y = @max(0, player2Y);
                } else {
                    player2MY = 0;
                }

                // Check for wall collision
                if (newBallY <= BALL_RADIUS + LINE_THICKNESS) {
                    // Recognice, if ball is on the top
                    ballMY = -ballMY;
                    rl.playSound(sound.borderCollision);
                }

                if (newBallX <= LINE_THICKNESS + BALL_RADIUS) {
                    // Recognice, if ball is on the left side
                    ballMX = -ballMX;
                    rl.playSound(sound.borderCollision);
                } else if (newBallX >= WINDOW_WIDTH - LINE_THICKNESS - BALL_RADIUS) {
                    // Recognice, if ball is on the right side
                    ballMX = -ballMX;
                    rl.playSound(sound.borderCollision);
                }

                const netLeftX = (WINDOW_WIDTH - LINE_THICKNESS) / 2;
                const netRightX = (WINDOW_WIDTH + LINE_THICKNESS) / 2;
                const netTopY = WINDOW_HEIGHT * (1 - NET_HEIGHT);
                if (rl.checkCollisionCircleRec(Vector2.init(@floatCast(newBallX), @floatCast(newBallY)), BALL_RADIUS, rl.Rectangle.init(netLeftX, netTopY, LINE_THICKNESS_FLOAT, WINDOW_WIDTH * NET_HEIGHT))) {
                    // Collision with Net
                    if (ballX <= netLeftX) {
                        // Collision top or left
                        const distanceToTop = netTopY - newBallY;
                        const distanceToLeft = netLeftX - newBallX;
                        if (distanceToTop > distanceToLeft) {
                            // Collision top
                            ballMY = -ballMY;
                            stayOverHight = netTopY;
                        } else {
                            // Collision left
                            ballMX = -ballMX;
                            stayLeftFrom = netLeftX;
                        }
                    } else if (ballX > netLeftX and ballX < netRightX) {
                        // Collision top
                        ballMY = -ballMY;
                        stayOverHight = netTopY;
                    } else {
                        // Collision top or right
                        const distanceToTop = netTopY - newBallY;
                        const distanceToRight = newBallX - netRightX;
                        if (distanceToTop > distanceToRight) {
                            // Collision top
                            ballMY = -ballMY;
                            stayOverHight = netTopY;
                        } else {
                            // Collision right
                            ballMX = -ballMX;
                            stayRightFrom = netRightX;
                        }
                    }
                    rl.playSound(sound.borderCollision);
                }

                // Check for ball-player collision
                ballHasCollisionThisFrame = false;
                checkPlayerCollision(true, newBallX, newBallY);
                checkPlayerCollision(false, newBallX, newBallY);
                if (!ballHasCollisionThisFrame) {
                    ballHadCollisionLastFrame = false;
                }

                if (stayLeftFrom - BALL_RADIUS > ballX + ballMX and stayRightFrom + BALL_RADIUS < ballX + ballMX) {
                    ballX += ballMX;
                } else {
                    if (stayLeftFrom != WINDOW_WIDTH) {
                        ballX = stayLeftFrom - BALL_RADIUS;
                    } else {
                        ballX = stayRightFrom + BALL_RADIUS;
                    }
                }
                ballY = @min(ballY + ballMY, stayOverHight - BALL_RADIUS);

                rl.drawCircle(@intFromFloat(@floor(ballX)), @intFromFloat(@floor(ballY)), BALL_RADIUS, WHITE);

                if (newBallY >= (WINDOW_HEIGHT - LINE_THICKNESS - BALL_RADIUS)) {
                    // Recognice, if ball is on the floor
                    if (ballX < WINDOW_WIDTH / 2) {
                        player2Score += 1;
                    } else {
                        player1Score += 1;
                    }
                    if ((player1Score == 7) or (player2Score == 7)) {
                        gameIsRunning = false;
                        deathScreen = true;
                    } else {
                        setStandardValues();
                    }
                    rl.playSound(sound.floor);
                }
            } else {
                if (@floor(pause) != 0) {
                    var buffer = [_]u8{undefined} ** 100;
                    const number: i32 = @intFromFloat(4 - @floor(pause));
                    if (lastBeepedNumber != 3 - @floor(pause)) {
                        rl.playSound(sound.countdown);
                        lastBeepedNumber = 3 - @floor(pause);
                    }
                    const interpolatedText = try std.fmt.bufPrintZ(&buffer, "{}", .{number});
                    const sizeOfText = rl.measureTextEx(rl.getFontDefault(), interpolatedText, 45, 0);
                    rl.drawText(interpolatedText, @intFromFloat(@floor((WINDOW_WIDTH - sizeOfText.x) / 2)), WINDOW_HEIGHT * 0.3, 45, ACCENTCOLOR);
                }
                if (player1Y != 0) {
                    player1MY -= rl.getFrameTime() * BALL_GRAVITY_CONSTANT;
                    player1Y += BALL_GRAVITY_CONSTANT * player1MY;
                    player1Y = @max(0, player1Y);
                }
                if (player2Y != 0) {
                    player2MY -= rl.getFrameTime() * BALL_GRAVITY_CONSTANT;
                    player2Y += BALL_GRAVITY_CONSTANT * player2MY;
                    player2Y = @max(0, player2Y);
                }
            }

            try drawGameLayout();

            // Draw players
            const player1PosX: i32 = @intFromFloat(player1X - PLAYER_WIDTH / 2);
            const player1PosY: i32 = @intFromFloat(WINDOW_HEIGHT - LINE_THICKNESS - PLAYER_HEIGHT - player1Y);
            const playerWidthThroughThree = PLAYER_WIDTH / 3;
            const playerHeightThroughFour = PLAYER_HEIGHT / 4;
            rl.drawRectangle(player1PosX, player1PosY, playerWidthThroughThree, PLAYER_HEIGHT, WHITE);
            rl.drawRectangle(player1PosX + playerWidthThroughThree, player1PosY + playerHeightThroughFour, playerWidthThroughThree, playerHeightThroughFour * 2, WHITE);
            rl.drawRectangle(player1PosX + playerWidthThroughThree * 2, player1PosY, playerWidthThroughThree, PLAYER_HEIGHT, WHITE);

            const player2PosX: i32 = @intFromFloat(player2X - PLAYER_WIDTH / 2);
            const player2PosY: i32 = @intFromFloat(WINDOW_HEIGHT - LINE_THICKNESS - PLAYER_HEIGHT - player2Y);
            rl.drawRectangle(player2PosX, player2PosY, playerWidthThroughThree, PLAYER_HEIGHT, WHITE);
            rl.drawRectangle(player2PosX + playerWidthThroughThree, player2PosY + playerHeightThroughFour, playerWidthThroughThree, playerHeightThroughFour * 2, WHITE);
            rl.drawRectangle(player2PosX + playerWidthThroughThree * 2, player2PosY, playerWidthThroughThree, PLAYER_HEIGHT, WHITE);
        } else {
            const x: i8 = if (player1Score > player2Score) 1 else 2;
            const y = @abs(player1Score - player2Score);
            var buffer = [_]u8{undefined} ** 100;
            const interpolatedPlayWonText = try std.fmt.bufPrintZ(&buffer, "PLAYER {} WON WITH {} POINTS DIFFERENCE", .{ x, y });

            const bigText = if (deathScreen) "GAME OVER" else "VOLLEYBALL";
            const smallText = if (deathScreen) interpolatedPlayWonText else "CREATED WITH <3 IN ZIG BY BOOTHOSH";

            const sizeOfBText = rl.measureTextEx(rl.getFontDefault(), bigText, 30, 0);
            const sizeOfSText = rl.measureTextEx(rl.getFontDefault(), smallText, 15, 0);

            const combinedHeight = sizeOfBText.y + sizeOfSText.y;

            const xBOffset = @as(i32, @intFromFloat(@floor((WINDOW_WIDTH - sizeOfBText.x) / 2)));
            const yBOffset = @as(i32, @intFromFloat(@floor((WINDOW_HEIGHT - combinedHeight) / 2)));

            rl.drawText(bigText, xBOffset, yBOffset, 30, ACCENTCOLOR);

            const xSOffset = @as(i32, @intFromFloat(@floor((WINDOW_WIDTH - sizeOfSText.x) / 2)));
            const ySOffset = @as(i32, @intFromFloat(@floor((WINDOW_HEIGHT - combinedHeight) / 2 + sizeOfBText.y)));

            rl.drawText(smallText, xSOffset, ySOffset, 15, ACCENTCOLOR);

            frameCount = frameCount + 1;
            if (@mod(frameCount, 60) < 49) {
                // PETP: Press Enter to play
                const sizeOfPETPText = rl.measureTextEx(rl.getFontDefault(), "Press [Enter] to play", 15, 0);

                const xPETPOffset = @as(i32, @intFromFloat(@floor((WINDOW_WIDTH - sizeOfPETPText.x) / 2)));
                const yPETPOffset = @as(i32, @intFromFloat(@floor((WINDOW_HEIGHT - sizeOfPETPText.y) * 0.75)));

                rl.drawText("Press [Enter] to play", xPETPOffset, yPETPOffset, 15, ACCENTCOLOR);
            }

            // Draw Start window and wait for return key beeing pressed
            if (rl.isKeyDown(rl.KeyboardKey.enter)) {
                startGame();
            }

            if (rl.isKeyPressed(.f)) {
                showFPS = !showFPS;
            }
            if (rl.isKeyPressed(.space)) {
                reverseJump = !reverseJump;
            }
        }
        var buffer = [_]u8{undefined} ** 10;
        if (showFPS) {
            const fpsText = try std.fmt.bufPrintZ(&buffer, "{d} FPS", .{@ceil((1 / rl.getFrameTime()))});
            rl.drawText(fpsText, 15, 15, 15, WHITE);
        }
        if (reverseJump) {
            const reverseJumpText = rl.measureText("Reverse", 15);
            rl.drawText("Reverse", WINDOW_WIDTH - 15 - reverseJumpText, 15, 15, WHITE);
        }
    }
}

pub fn drawGameLayout() !void {
    rl.drawLineEx(Vector2.init(0, LINE_THICKNESS / 2), Vector2.init(WINDOW_WIDTH, LINE_THICKNESS / 2), LINE_THICKNESS, WHITE);
    rl.drawLineEx(Vector2.init(LINE_THICKNESS / 2, 0), Vector2.init(LINE_THICKNESS / 2, WINDOW_HEIGHT - LINE_THICKNESS), LINE_THICKNESS, WHITE);
    rl.drawLineEx(Vector2.init(WINDOW_WIDTH - LINE_THICKNESS / 2, 0), Vector2.init(WINDOW_WIDTH - LINE_THICKNESS / 2, WINDOW_HEIGHT - LINE_THICKNESS), LINE_THICKNESS, WHITE);
    rl.drawLineEx(Vector2.init(WINDOW_WIDTH / 2, WINDOW_HEIGHT), Vector2.init(WINDOW_WIDTH / 2, WINDOW_HEIGHT * (1 - NET_HEIGHT)), LINE_THICKNESS, WHITE);
    rl.drawLineEx(Vector2.init(0, WINDOW_HEIGHT - LINE_THICKNESS / 2), Vector2.init(WINDOW_WIDTH, WINDOW_HEIGHT - LINE_THICKNESS / 2), LINE_THICKNESS, rl.Color.gray);
    var buffer = [_]u8{undefined} ** 7;
    const player1ScoreText = try std.fmt.bufPrintZ(&buffer, "{} / 7", .{player1Score});
    rl.drawText(player1ScoreText, LINE_THICKNESS * 3, LINE_THICKNESS * 3, 25, WHITE);
    const player2ScoreText = try std.fmt.bufPrintZ(&buffer, "{} / 7", .{player2Score});
    const sizeOfText = rl.measureTextEx(rl.getFontDefault(), player2ScoreText, 25, 0);
    rl.drawText(player2ScoreText, WINDOW_WIDTH - LINE_THICKNESS * 4 - @as(i32, @intFromFloat(sizeOfText.x)), LINE_THICKNESS * 3, 25, WHITE);
    if (player1Score == 6 or player2Score == 6) {
        const sizeOfMatchpointText = rl.measureTextEx(rl.getFontDefault(), "Match point", 25, 0);
        rl.drawText("Match point", @as(i32, @intFromFloat((WINDOW_WIDTH - sizeOfMatchpointText.x) / 2)), LINE_THICKNESS * 3, 25, ACCENTCOLOR);
    }
}

pub fn startGame() void {
    gameIsRunning = true;
    player1Score = 0;
    player2Score = 0;
    player1X = WINDOW_WIDTH * 0.35;
    player1Y = 0;
    player2X = WINDOW_WIDTH * 0.65;
    player2Y = 0;
    player1MY = 0;
    player2MY = 0;
    setStandardValues();
}

pub fn setStandardValues() void {
    ballX = WINDOW_WIDTH / 2;
    ballY = WINDOW_HEIGHT * 0.3;
    ballMX = if (shootBallLeft) -2 else 2;
    ballMY = -3;
    pauseSince = rl.getTime();
    shootBallLeft = !shootBallLeft;
}

pub fn checkPlayerCollision(playerNumberOne: bool, newBallX: f64, newBallY: f64) void {
    const playerLeftX = (if (playerNumberOne) player1X else player2X) - PLAYER_WIDTH / 2;
    const playerRightX = playerLeftX + PLAYER_WIDTH;
    const playerTopY = WINDOW_HEIGHT - LINE_THICKNESS - PLAYER_HEIGHT - (if (playerNumberOne) player1Y else player2Y);
    if (rl.checkCollisionCircleRec(Vector2.init(@floatCast(newBallX), @floatCast(newBallY)), BALL_RADIUS, rl.Rectangle.init(@floatCast(playerLeftX), @floatCast(playerTopY), PLAYER_WIDTH, PLAYER_HEIGHT))) {
        ballHasCollisionThisFrame = true;
        if (!ballHadCollisionLastFrame) {
            // Collision detected!
            const distanceToPlayerLeft = playerLeftX - newBallX;
            const distanceToPlayerRight = newBallX - playerRightX;
            const distanceToPlayerTop = playerTopY - newBallY;
            if (distanceToPlayerLeft > 0 and distanceToPlayerLeft <= BALL_RADIUS) {
                if (distanceToPlayerTop > 0 and distanceToPlayerTop <= BALL_RADIUS) {
                    // On the corner
                    if (ballMY > 0) {
                        ballMY = -ballMY;
                    }
                    ballMY -= 0.3 * player2MY;
                    // Check if it should switch x direction
                    if (ballMX > 0) {
                        ballMX = -ballMX;
                    } else {
                        ballMX *= 1.5;
                    }
                } else {
                    stayLeftFrom = playerLeftX;
                    ballMX = -ballMX;
                }
            } else if (distanceToPlayerRight > 0 and distanceToPlayerRight <= BALL_RADIUS) {
                if (distanceToPlayerTop > 0 and distanceToPlayerTop <= BALL_RADIUS) {
                    // On the corner
                    if (ballMY > 0) {
                        ballMY = -ballMY;
                    }
                    ballMY -= 0.3 * player2MY;
                    stayOverHight = playerTopY;
                    // Check if it should switch x direction
                    if (ballMX < 0) {
                        ballMX = -ballMX;
                    } else {
                        ballMX *= 1.5;
                    }
                } else {
                    stayRightFrom = playerRightX;
                    ballMX = -ballMX;
                }
            } else if (distanceToPlayerTop > 0 and distanceToPlayerTop <= BALL_RADIUS) {
                // Top
                if (ballMY > 0) {
                    ballMY = -ballMY;
                }
                ballMY -= 0.3 * player2MY;
                stayOverHight = playerTopY;
            } else {
                std.debug.print("unusual\n", .{});
                if (distanceToPlayerLeft > distanceToPlayerTop or distanceToPlayerRight > distanceToPlayerTop) {
                    ballMX = -ballMX;
                    if (distanceToPlayerLeft > distanceToPlayerRight) {
                        stayLeftFrom = playerLeftX;
                    } else {
                        stayRightFrom = playerRightX;
                    }
                } else {
                    if (ballMY > 0) {
                        ballMY = -ballMY;
                    }
                    stayOverHight = playerTopY;
                    ballMY -= 0.3 * player2MY;
                }
            }
            rl.playSound(sound.playerCollision);
        }
    }
}
