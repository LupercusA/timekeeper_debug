--------------------------------------------------------
-- Minetest :: Debug Console Mod (console)
--
-- See README.txt for licensing and release notes.
-- Copyright (c) 2020, Leslie E. Krause
--
-- ./games/minetest_game/mods/console/init.lua
--------------------------------------------------------

local config = minetest.load_config( {
	default_size = "none",
	max_output_lines = 17,
	max_review_lines = 100,
	has_line_numbers = false,
} )
local player_huds = { }
local buffer = { }
local output = ""
local pipes = { }
local log_file

local unsafe_funcs = {
	["pairs"] = true,
	["ipairs"] = true,
	["next"] = true,
	["tonumber"] = true,
	["tostring"] = true,
	["printf"] = true,
	["assert"] = true,
	["error"] = true,
}

----------------

local gsub = string.gsub
local join = table.join
local max = math.max
local sprintf = string.format
local insert = table.insert

function printf( str, ... )
	if type( str ) == "table" then
		str = join( str, " ", function ( i, v )
			return tostring( v )
		end, true )
	elseif type( str ) ~= "string" then
		str = tostring( str )
	end
	if #{ ... } > 0 then
		str = sprintf( str, ... )
	end

	gsub( str .. "\n", "(.-)\n", function ( line )
		insert( buffer, line )
	end )

	output = ""

	for i = max( 1, #buffer - config.max_output_lines + 1 ), #buffer do
		if config.has_line_numbers then
			output = output .. sprintf( "%03d: %s\n", i, buffer[ i ], "\n" )
		else
			output = output .. buffer[ i ] .. "\n"
		end
	end

	for name, data in pairs( player_huds ) do
		if data.size ~= "none" then
			data.player:hud_change( data.refs.body_text, "text", output )
		end
	end
end

----------------

local _ = nil

local function is_match( text, glob )
     -- use underscore variable to preserve captures
     _ = { string.match( text, glob ) }
     return #_ > 0
end

local function parse_id( param )
	if is_match( param, "^([a-zA-Z][a-zA-Z0-9_]+)$" ) then
		return { method = _[ 1 ] }
	elseif is_match( param, "^([a-zA-Z][a-zA-Z0-9_]+)%.([a-zA-Z][a-zA-Z0-9_]+)$" ) then
		return { parent = _[ 1 ], method = _[ 2 ] }
	end
	return nil
end

local function resize_hud( name, size )
	local data = player_huds[ name ]
	local player = data.player
	local refs = data.refs

	if size == data.size then return end

	if refs then
		player:hud_remove( refs.head_bg )
		player:hud_remove( refs.head_text )
		player:hud_remove( refs.head_icon )
		player:hud_remove( refs.body_bg )
		player:hud_remove( refs.body_text )
	end

	if size == "none" then
		refs = nil
	else
		refs = { }

		refs.body_bg = player:hud_add( {
			hud_elem_type = "image",
			text = "default_cloud.png^[colorize:#000000DD",
			position = { x = size == "full" and 0.0 or 0.6, y = 0.5 },
			scale = { x = -100, y = -50 },
			alignment = { x = 1, y = 0 },
		} )

		refs.body_text = player:hud_add( {
			hud_elem_type = "text",
			text = output,
			number = 0xFFFFFF,
			position = { x = size == "full" and 0.0 or 0.6, y = 0.25 },
			alignment = { x = 1, y = 1 },
			offset = { x = 8, y = 38 },
		} )

		refs.head_bg = player:hud_add( {
			hud_elem_type = "image",
			text = "default_cloud.png^[colorize:#222222CC",
			position = { x = size == "full" and 0.0 or 0.6, y = 0.25 },
			scale = { x = -100, y = 2 },
			alignment = { x = 1, y = 1 },
		} )

		refs.head_text = player:hud_add( {
			hud_elem_type = "text",
			text = "Debug Console",
			number = 0x999999,
			position = { x = size == "full" and 0.0 or 0.6, y = 0.25 },
			alignment = { x = 1, y = 1 },
			offset = { x = 36, y = 8 },
		} )

		refs.head_icon = player:hud_add( {
			hud_elem_type = "image",
			text = "debug.png",
			position = { x = size == "full" and 0.0 or 0.6, y = 0.25 },
			scale = { x = 1, y = 1 },
			alignment = { x = 1, y = 1 },
			offset = { x = 6, y = 4 },
		} )
	end

	data.refs = refs
	data.size = size
end

----------------

minetest.register_privilege( "debug", {
	description = "Manage and review the debugging console.",
	give_to_singleplayer = true,
} )

minetest.register_on_joinplayer( function( player )
	local pname = player:get_player_name( )

	if minetest.check_player_privs( pname, "debug" ) then
		player_hudelete then
			if not delete_config( mod_name ) then
				minetest.destroy_form( player_name )
				minetest.chat_send_player( player_name, "Unable to delete configuration file." )
			end
			content = nil
			minetest.update_form( player_name, get_formspec ( ) )

		elseif fields.create then
			if not create_config( mod_name ) then
				minetest.destroy_form( player_name )
				minetest.chat_send_player( player_name, "Unable to create configuration file." )
			end
			content = ""
			minetest.update_form( player_name, get_formspec ( ) )

		elseif fields.origin then
			reset_origin_map( fields.origin )
			content = load_config( mod_name )
			minetest.update_form( player_name, get_formspec ( ) )

		end
	end

	reset_origin_map( 1 )
	content = load_config( mod_name )

	minetest.create_form( nil, player_name, get_formspec( ), on_close )
end

--------------------
-- Public Methods --
--------------------

minetest.load_config = function ( base_config, options )
	local name = minetest.get_current_modname( )
	local path = minetest.get_modpath( name )
	local config = base_config or { }
	local status

	if not options then options = { } end
	
	config.core = {
		MOD_NAME = name,
		MOD_PATH = path,
		WORLD_PATH = world_path,
		tonumber = tonumber,
		tostring = tostring,
		sprintf = string.format,
		tolower = string.lower,
		toupper = string.upper,
		concat = table.concat,
		random = math.random,
		max = math.max,
		min = math.min,
		print = print,
		next = next,
		pairs = pairs,
		ipairs = ipairs,
		date = os.date,
		time = os.time,
		assert = assert,
		error = error,
	}

	if options.can_override then
		status = import( config, path .. "/config.lua" )
		status = import( config, world_path .. "/config/" .. name .. ".lua" ) or status
	else
		status = import( config, path .. "/config.lua" ) or import( config, world_path .. "/config/" .. name .. ".lua" )
	end

	if not status then
		minetest.log( "warning", "Missing configuration file for mod \"" .. name .. "\"" )
	end

	configured_mods[ name ] = {
		base_config = base_config,
		can_refresh = options.can_refresh,
		can_override = options.can_override,
	}
	config.core = nil

	return config
end

------------------------------
-- Registered Chat Commands --
------------------------------

minetest.register_chatcommand( "config", {
	description = "View and edit the configuration for a given mod.",
	privs = { server = true },
	func = function( player_name, param )
		if not env then
			return false, "This feature is disabled in a secure environment."
		elseif not minetest.create_form then
			return false, "This feature is not supported."
		end

		if not string.match( param, "^[a-zA-Z0-9_]+$" ) then
			return false, "Invalid mod name." 
		elseif not configured_mods[ param ] then
			return false, "Configuration not available."
		end

		open_config_editor( player_name, param )
		return true
	end
} )
safe_funcs[ param ] then
			local class = parse_id( param )

			if class and not pipes[ param ] then
				local func

				if not class.parent then
					func = _G[ class.method ]
				elseif _G[ class.parent ] then
					func = _G[ class.parent ][ class.method ]
				end

				if func then
					pipes[ param ] = { func = func, class = class }

					local new_func = function( ... )
						local args = { "[" .. param .. "]", ... }
						for i = 2, #args do
							args[ i ] = tostring( args[ i ] )
						end
						printf( args )
		
						return func( ... )
					end

					if class.parent then
						_G[ class.parent ][ class.method ] = new_func
					else
						_G[ class.method ] = new_func
					end

					return true, "Function pipe created."
				end
			end
		end

		return false, "Failed to create function pipe."
	end
} )

globaltimer.start( 1.0, "console:slurp_file", function ( )
	if log_file then
		local str = log_file:read( "*a" )
		if str ~= "" then
			printf( string.match( str, "(.-)\n?$" ) )  -- remove trailing newline
		end
	end
end )

globaltimer.start( 0.2, "console:resize_huds", function( )
	for name, data in pairs( player_huds ) do
		local controls = data.player:get_player_control( )

		if controls.sneak and controls.aux1 then
			if data.size == "half" then
				resize_hud( name, "full" )
			elseif data.size == "full" then
				resize_hud( name, "none" )
			else
				resize_hud( name, "half" )
			end

		end
	end
end )
