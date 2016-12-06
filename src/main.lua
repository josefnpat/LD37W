require "utility"

local music = love.audio.newSource("assets/music/Marsel_Minga_-_05_-_Saturn.mp3")
music:setLooping(true)
music:play()

libs = {
	sti = require "libs.sti",
	tiny = require "libs.tiny",
	gamestate = require "libs.gamestate",
	healthcolor = require "libs.healthcolor",
	bump = require "libs.bump",
}

states = {
	game = require "states.game",
}

fonts = {
	default = love.graphics.getFont(),
	gameover = love.graphics.newFont("assets/fonts/Bungee-Regular.ttf",64),
}

function love.load()
	libs.gamestate.registerEvents()
	libs.gamestate.switch(states.game)
end
