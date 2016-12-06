local game = {}

function game:init()
	love.graphics.setDefaultFilter("nearest")
	self.ss = love.graphics.newImage("assets/ss.png")
	local w,h = self.ss:getWidth(),self.ss:getHeight()
	self.assets = {
		base = love.graphics.newQuad(15*64,1*64,64,64,w,h),
		miner = {
			love.graphics.newQuad(17*64,3*64,64,64,w,h),
			love.graphics.newQuad(17*64,4*64,64,64,w,h),
			love.graphics.newQuad(17*64,5*64,64,64,w,h),
			love.graphics.newQuad(17*64,6*64,64,64,w,h),
		},
		tank = {
			love.graphics.newQuad(15*64,3*64,64,64,w,h),
			love.graphics.newQuad(15*64,4*64,64,64,w,h),
			love.graphics.newQuad(15*64,5*64,64,64,w,h),
			love.graphics.newQuad(15*64,6*64,64,64,w,h),
		}
	}
end

function game:enter()
	self.map = libs.sti("assets/map0.tmx.lua")

	self.bump = libs.bump.newWorld(64)

	self.world = libs.tiny.world()

	self.unitSystem = libs.tiny.processingSystem()
	self.unitSystem.filter = libs.tiny.requireAll("name","owner","x","y")

	function self.unitSystem:process(e,dt)
		local g = states.game
		if e.regen then
			e.hp = math.min(e.max_hp,e.hp + dt*e.regen)
		end
		if e.damage and e.range then
			for _,other in pairs(self.entities) do
				if e.owner ~= other.owner then
					local distance = math.distance(e.x,e.y,other.x,other.y)
					if distance < e.range then
						other.hp = math.max(0,other.hp - e.damage*dt)
						if other.hp <= 0 then
							g.world:removeEntity(other)
							if g.bump:hasItem(other) then
								g.bump:remove(other)
							end
						end
						other.inc_shots = other.inc_shots or {}
						table.insert(other.inc_shots,{
							x = math.random(-16,16),
							y = math.random(-16,16),
							dt = 1/15,
							max_dt = 1/15,
						})
					end
				end
			end
		end
		if e.ai == "build" then
			if e.build then
				e.build = math.min(e.max_build,e.build + dt)
				if e.build == e.max_build then
					e.build,e.max_build = nil,nil

					local ai = "wander"
					if e.owner == 1 then
						ai = nil
					end

					local unit = {
						name = "tank",
						class = "unit",
						owner = e.owner,
						regen = 0.25,
						x = e.x,
						y = e.y,
						hp = 10,
						max_hp = 10,
						speed = 50,
						max_speed = 50,
						tx = math.random(
							love.graphics.getWidth()/8,
							love.graphics.getWidth()*7/8),
						ty = math.random(
							love.graphics.getHeight()/8,
							love.graphics.getHeight()*7/8),
						damage = 10,
						range = 128,
						ai = ai,
					}
					g.world:addEntity(unit)
					g.bump:add(unit,unit.x,unit.y,64,64)

				end
			else
				if g.players[e.owner].resources >= 25 then
					g.players[e.owner].resources = g.players[e.owner].resources - 25
					e.build,e.max_build = 0,5
				end
			end
		elseif e.ai == "wander" then
			if e.tx == nil and e.ty == nil then
				e.tx = math.random(
					love.graphics.getWidth()/8,
					love.graphics.getWidth()*7/8)
				e.ty = math.random(
					love.graphics.getHeight()/8,
					love.graphics.getHeight()*7/8)
			else
				local distance = math.distance(e.x,e.y,e.tx,e.ty)
				if distance < 4 then
					e.tx,e.ty = nil,nil
				end
			end
		elseif e.ai == "mine" then
			if e.tx == nil and e.ty == nil then

				if e.resources == e.max_resources then

					-- go to nearest base
					local closest,closest_distance = nil,math.huge
					for _,other in pairs(self.entities) do
						if other.name == "base" and other.owner == e.owner then
							local distance = math.distance(e.x,e.y,other.x,other.y)
							if distance < closest_distance then
								closest,closest_distance = other,distance
							end
						end
					end
					if closest then
						e.tx,e.ty = closest.x,closest.y
					end

				else

					-- go to nearest minerals
					local closest,closest_distance = nil,math.huge
					for cy,daty in pairs(g.map.layers.resource.data) do
						for cx,dat in pairs(daty) do
							local distance = math.distance(e.x,e.y,(cx-1)*64,(cy-1)*64)
							if distance < closest_distance then
								closest,closest_distance = {cx,cy},distance
							end
						end
					end
					if closest then
						e.tx,e.ty = (closest[1]-1)*64,(closest[2]-1)*64
					end

				end


			end
		end

		if e.speed and e.tx and e.ty and g.bump:hasItem(e) then
			local distance = math.distance(e.x,e.y,e.tx,e.ty)
			if distance > 4 then
				local dx,dy = e.tx - e.x,e.ty - e.y
				local angle = math.atan2(dy,dx)
				local rtx = e.x + math.cos(angle)*dt*e.speed
				local rty = e.y + math.sin(angle)*dt*e.speed
				local ax,ay, cols, len = g.bump:move(e,rtx,rty,function(item,other)
					if item.no_unit_collision and item.class == "unit" and other.class == "unit" then
						return false
					else
						return "slide"
					end
				end)
				e.direction = e.x > ax and -1 or 1
				for _,col in pairs(cols) do
					if e.resources and col.other.name == "base" and col.other.owner == e.owner then
						if e.resources > dt then
							g.players[e.owner].resources = g.players[e.owner].resources + dt*10
							e.resources = e.resources - dt
						else
							g.players[e.owner].resources = g.players[e.owner].resources + e.resources*10
							e.resources = 0
							e.tx,e.ty = nil,nil
						end
					end
				end
				e.x,e.y = ax,ay
			else
				e.tx,e.ty = nil
			end
		end
		--info according to the map
		local ex,ey = math.floor( (e.x+32)/64)+1,math.floor( (e.y+32)/64)+1
		if e.max_resources then
			local rd = g.map.layers.resource.data
			if rd[ey] and rd[ey][ex] then
				e.resources = math.min(e.max_resources,e.resources+dt)
			end
		end
		if e.max_speed then
			local td = g.map.layers.tree.data
			if td[ey] and td[ey][ex] then
				e.speed = e.max_speed/4
			else
				e.speed = e.max_speed
			end
			local rd = g.map.layers.road.data
			if rd[ey] and rd[ey][ex] then
				e.speed = e.max_speed*1.5
			end
		end
	end
	self.world:addSystem(self.unitSystem)

	local drawSystem = libs.tiny.processingSystem()
	drawSystem.filter = libs.tiny.requireAll("name","hp","max_hp")
	function drawSystem:process(e)
		local g = states.game
		if e.selected then
			love.graphics.rectangle("line",e.x,e.y,64,64)
		end
		local img = g.assets[e.name]
		if type(img) == "table" then
			img = img[e.owner]
		end
		love.graphics.draw(g.ss,img,e.x+32,e.y+32,
			0,e.direction or 1,1,32,32)
		love.graphics.setColor(31,31,31,127)
		love.graphics.rectangle("fill",e.x,e.y+56,64,8)
		local percent_hp = math.min(1,math.max(0,e.hp/e.max_hp))
		if e.resources and e.resources > 0 then
			local percent_resources = math.min(1,math.max(0,e.resources/e.max_resources))
			love.graphics.setColor(0,191,191)
			love.graphics.rectangle("fill",e.x,e.y+56+1,(64-2)*percent_resources,4-2)
			love.graphics.setColor(libs.healthcolor(percent_hp))
			love.graphics.rectangle("fill",e.x,e.y+56+1+4,(64-2)*percent_hp,8-2-4)
		elseif e.build and e.build > 0 then
			local percent_build = math.min(1,math.max(0,e.build/e.max_build))
			love.graphics.setColor(191,191,0)
			love.graphics.rectangle("fill",e.x,e.y+56+1,(64-2)*percent_build,4-2)
			love.graphics.setColor(libs.healthcolor(percent_hp))
			love.graphics.rectangle("fill",e.x,e.y+56+1+4,(64-2)*percent_hp,8-2-4)
		else
			love.graphics.setColor(libs.healthcolor(percent_hp))
			love.graphics.rectangle("fill",e.x,e.y+56+1,(64-2)*percent_hp,8-2)
		end
		if e.inc_shots then
			for ishot,shot in pairs(e.inc_shots) do
				love.graphics.setColor(math.random(191,255),math.random(0,255),0,127)
				local percent = math.min(1,math.max(0,shot.dt/shot.max_dt))
				love.graphics.circle("fill",e.x+shot.x+32,e.y+shot.y+32,16*percent)
				local dt = love.timer.getDelta()
				shot.dt = shot.dt - dt
				if shot.dt <= 0 then
					table.remove(e.inc_shots,ishot)
				end
			end
		end
		love.graphics.setColor(255,255,255)
		if debug_mode then
			love.graphics.print("speed:"..(e.speed or 0).."\nai:"..(e.ai or "n/a"),e.x,e.y)
			love.graphics.circle("line",e.x+32,e.y+32,e.range or 0)
			if e.tx and e.ty then
				love.graphics.line(e.x,e.y,e.tx,e.ty)
			end
		end
	end
	self.world:addSystem(drawSystem)

	self.players = {}
	for i,startpos in pairs(self.map.layers.start.objects) do
		local player = {
			start = startpos,
			resources = 0,
		}
		table.insert(self.players,player)
		local unit = {
			name = "base",
			class = "building",
			owner = i,
			x = startpos.x,
			y = startpos.y,
			hp = 100,
			max_hp = 100,
			ai = "build",
		}
		self.world:addEntity(unit)
		self.bump:add(unit,unit.x,unit.y,64,64)

		local miner = {
			name = "miner",
			class = "unit",
			no_unit_collision = true,
			owner = i,
			x = startpos.x,
			y = startpos.y,
			hp = 10,
			max_hp = 10,
			speed = 100,
			max_speed = 100,
			resources = 0,
			max_resources = 4,
			ai = "mine",
		}
		self.world:addEntity(miner)
		self.bump:add(miner,miner.x,miner.y,64,64)
	end

end

function game:update(dt)
	if self.gameover then
		self.gameover.dt = self.gameover.dt - dt
		if self.gameover.dt <= 0 then
			libs.gamestate.switch(states.game)
		end
	elseif self.unitSystem.entities then
		for _,p in pairs(self.players) do
			p.count = 0
		end
		local enemy = 0
		for _,e in pairs(self.unitSystem.entities) do
			if e.owner ~= 1 then
				enemy = enemy + 1
			end
			self.players[e.owner].count = self.players[e.owner].count + 1
		end
		if enemy == 0 then
			self.gameover = {msg="GAME OVER: YOU ARE VICTORIOUS!",dt=5}
		elseif self.players[1].count == 0 then
			self.gameover = {msg="GAMVE OVER: YOU HAVE FAILED.",dt=5}
		end
	end
end

function game:draw()
	local dt = love.timer.getDelta()
	self.map:draw()
	self.world:update(dt)
	if self.startsel then
		love.graphics.rectangle("line",
			self.startsel[1],
			self.startsel[2],
			love.mouse.getX()-self.startsel[1],
			love.mouse.getY()-self.startsel[2])
	end

	if debug_mode then
		local info = ""
		for ip,p in pairs(self.players) do
			info = info .. "Player "..ip..": Resource - "..math.floor(p.resources).." "
		end
		love.graphics.print(info,
			0,love.graphics.getHeight()-love.graphics.getFont():getHeight())
	end

	if self.gameover then
		love.graphics.setFont(fonts.gameover)
		love.graphics.printf(self.gameover.msg,
			0,(love.graphics.getHeight() - love.graphics.getFont():getHeight())/2,
			love.graphics.getWidth(),"center")
		love.graphics.setFont(fonts.default)
	end

end

function game:mousepressed(x,y,button)
	if button == 1 then
		self.startsel = {x,y}
	elseif button == 2 then
		for _,e in pairs(self.unitSystem.entities) do
			if e.selected then
				e.tx,e.ty = x-32,y-32
			end
		end
	end
end

function game:mousereleased(x,y,button)
	if self.startsel then
		local xmin,xmax = math.min(self.startsel[1],x),math.max(self.startsel[1],x)
		local ymin,ymax = math.min(self.startsel[2],y),math.max(self.startsel[2],y)
		for _,e in pairs(self.unitSystem.entities) do
			e.selected = nil
			if e.x+32 >= xmin and e.x+32 < xmax and
				e.y+32 >= ymin and e.y+32 < ymax and e.owner == 1 then
				e.selected = true
			end
		end
		self.startsel = nil
	end
end

function game:keypressed(key)
	if key == "`" then
		debug_mode = not debug_mode
	end
end

return game
