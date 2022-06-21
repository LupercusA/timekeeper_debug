function Timekeeper( this )
	local timer_defs = { }
	local pending_timer_defs = { }
	local clock = 0.0
	local self = { }

	self.start = function ( period, name, func, delay )
		if timer_defs[ name ] then
			timer_defs[ name ] = nil
		end
		pending_timer_defs[ name ] = { cycles = 0, period = period, expiry = clock + period + ( delay or 0.0 ), started = clock, func = func }
	end

	self.start_now = function ( period, name, func )
		if timer_defs[ name ] then
			timer_defs[ name ] = nil
		end
		if not func( this, 0, period, 0.0, 0.0 ) then
			pending_timer_defs[ name ] = { cycles = 0, period = period, expiry = clock + period, started = clock, func = func }
		end
	end

	self.clear = function ( name )
		pending_timer_defs[ name ] = nil
		if timer_defs[ name ] then
			timer_defs[ name ] = nil
		end
	end

	self.on_step = function ( dtime )
		S1()
		clock = clock + dtime

		for k, v in pairs( pending_timer_defs ) do
			timer_defs[ k ] = v
			pending_timer_defs[ k ] = nil
		end

		local timers = { }
		for k, v in pairs( timer_defs ) do
			if clock >= v.expiry and clock > v.started then
				v.expiry = clock + v.period
				v.cycles = v.cycles + 1
				-- callback( this, cycles, period, elapsed, overrun )
				if v.func and v.func( this, v.cycles, v.period, clock - v.started, clock - v.expiry ) then
					self.clear( k )
				end
				timers[ k ] = v
			end
		end
		S1_()
		return timers
	end

	return self
end

globaltimer = Timekeeper( { } )

minetest.register_globalstep( function ( dtime )
	globaltimer.on_step( dtime )
end )
