/*
	released to the public domain
	no warranty is implied; use at your own risk
*/

package flickgame

import "shared:lena"

import "core:os"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:encoding/json"

Context :: struct {
	is_playing: bool,
	is_drawing: bool,

	current_color: u8,
	current_size:  int,
	current_image: int,

	// we only serialise this
	using game: Flick_Game,
}

Flick_Game :: struct {
	images:   [16]lena.Image,
	mappings: [17]int,
}

// https://lospec.com/palette-list/woodspark
WOODSPARK :: [16]u32 {
	0xfff5eeb0, 0xfffabf61, 0xffe08d51, 0xff8a5865,
	0xff452b3f, 0xff2c5e3b, 0xff609c4f, 0xffc6cc54,
	0xff78c2d6, 0xff5479b0, 0xff56546e, 0xff839fa6,
	0xffe0d3c8, 0xfff05b5b, 0xff8f325f, 0xffeb6c98,
}

BUFFER_WIDTH  :: 148
BUFFER_HEIGHT :: 100

ADDITIONAL_WIDTH  :: 44
ADDITIONAL_HEIGHT :: 30

BACKGROUND :: 4

main :: proc() {
	arena: virtual.Arena
	err := virtual.arena_init_growing(&arena, 1024 * 1024)
	allocator := virtual.arena_allocator(&arena)
	defer free_all(allocator)

	ctx: Context = {
		current_size  = 4,
		current_image = 0,
		current_color = 8,
	}

	args := os.args[1:]
	if len(args) > 0 {
		unmarshal_json(&ctx.game, args[0], allocator = allocator)
		ctx.is_playing = true
	} else {
		for index in 0..<16 {
			ctx.images[index] = lena.create_image(BUFFER_WIDTH, BUFFER_HEIGHT, allocator)
			lena.clear_image(ctx.images[index], 1)
			ctx.mappings[index] = 16
		}
	}

	W :: BUFFER_WIDTH  + ADDITIONAL_WIDTH
	H :: BUFFER_HEIGHT + ADDITIONAL_HEIGHT

	lena_ctx := lena.init("Lena: FlickGame", W, H, lena.FPS_AUTO)
	defer lena.destroy()

	lena.set_palette(WOODSPARK)
	lena.set_alpha_index(BACKGROUND)
	lena.set_window_background(BACKGROUND)
	lena.set_mask_color(2) // just used for our manual glyph drawing

	for _ in lena.step() {
		if lena.key_pressed(.SPACE) {
			ctx.is_playing = !ctx.is_playing
		}

		if lena.key_pressed(.ESCAPE) {
			ctx.is_playing = false
		}

		if lena.key_pressed(.F11) {
			lena.toggle_fullscreen()
		}

		if lena.key_pressed(.RETURN) {
			result := marshal_json(ctx.game, "flickgame.json")
			if !result {
				fmt.println("failed to write flickgame.json")
			}
		}

		lena.clear_screen(BACKGROUND)

		if ctx.is_playing {
			play_game(&ctx)
		} else {
			edit_game(&ctx)
		}
	}
}

play_game :: proc(ctx: ^Context) {
	mx, my    := lena.get_cursor()
	the_image := ctx.images[ctx.current_image]

	lena.draw_image_scaled(the_image, {0, 0, 148, 100}, {0, 0, 148 + ADDITIONAL_WIDTH, 100 + ADDITIONAL_HEIGHT})

	if lena.mouse_pressed(.LEFT) {
		index := cast(int) lena.get_pixel(mx, my)

		mapping := ctx.mappings[index]
		if mapping < 16 {
			ctx.current_image = mapping
		}
	}
}

edit_game :: proc(ctx: ^Context) {
	mx, my    := lena.get_cursor()
	mx -= ADDITIONAL_WIDTH / 2

	the_image := ctx.images[ctx.current_image]

	if lena.mouse_pressed(.LEFT) && lena.is_inside({0, 0, the_image.w, the_image.h}, mx, my) {
		ctx.is_drawing = true
	}

	if lena.mouse_released(.LEFT) {
		ctx.is_drawing = false
	}

	if lena.mouse_pressed(.MIDDLE) {
		ctx.current_color = lena.get_pixel_on_image(the_image, mx, my)
	}

	if lena.mouse_pressed(.RIGHT) {
		index := lena.get_pixel_on_image(the_image, mx, my)
		flood_fill(the_image, index, ctx.current_color, mx, my)
	}

	if lena.key_pressed(.LEFT_BRACKET) {
		ctx.current_size = max(ctx.current_size - 1, 0)
	}

	if lena.key_pressed(.RIGHT_BRACKET) {
		ctx.current_size = min(ctx.current_size + 1, 16)
	}

	if ctx.is_drawing {
		lena.draw_circle_to_image(the_image, mx, my, ctx.current_size, ctx.current_color, true)
	}

	lena.set_alpha_index(0)

	for index in 0..<16 {
		rect: lena.Rect

		rect.x = index * 7 + 2 + ADDITIONAL_WIDTH / 2
		rect.y = BUFFER_HEIGHT + 2
		rect.w = 6
		rect.h = 6

		lena.set_draw_state()

		index_u8 := cast(u8) index

		if lena.mouse_pressed(.LEFT) && lena.is_inside(rect, mx + ADDITIONAL_WIDTH / 2, my) {
			ctx.current_color = index_u8
		}

		lena.draw_rect(rect, index_u8, true)
		if ctx.current_color == index_u8 {
			lena.draw_rect(rect, 12, false)
		}

		rect.y = BUFFER_HEIGHT + 9
		rect.w = lena.FONT_WIDTH  + 1
		rect.h = lena.FONT_HEIGHT - 1

		lena.set_draw_state({.MASK})

		image := lena.get_glyph(linear_to_ascii_hex(index))

		if lena.is_inside(rect, mx + ADDITIONAL_WIDTH / 2, my) {
			if lena.mouse_pressed(.LEFT) {
				ctx.current_image = index
			}
			lena.draw_rect(rect, 12, true)
		}

		lena.draw_image(image, rect.x + 1, rect.y)

		rect.y += 11
		mapped := lena.get_glyph(linear_to_ascii_hex(ctx.mappings[index]))

		if lena.is_inside(rect, mx + ADDITIONAL_WIDTH / 2, my) {
			if lena.mouse_pressed(.LEFT) {
				ctx.mappings[index] = (ctx.mappings[index] + 1) % 17
			}

			lena.draw_rect(rect, 12, true)
		}

		lena.draw_image(mapped, rect.x + 1, rect.y)
	}

	lena.set_draw_state()
	lena.set_alpha_index(BACKGROUND)

	lena.draw_image(the_image, ADDITIONAL_WIDTH / 2, 0)

	if !ctx.is_drawing && lena.is_inside({0, 0, the_image.w, the_image.h}, mx, my) {
		lena.draw_circle(mx + ADDITIONAL_WIDTH / 2, my, ctx.current_size, ctx.current_color, false)
	}
}

// turns one mass of colour into another index, starting at a point
flood_fill :: proc(target: lena.Image, old, new: u8, x, y: int) {
	if old == new do return
	if x < 0 || y < 0 || x >= target.w || y >= target.h do return

	index := x + y * target.w
	if target.pixels[index] != old {
		return
	}

	stack := make([dynamic]int, 0, len(target.pixels), context.temp_allocator)
	append(&stack, index)

	i: int
	for len(stack) > 0 {
		the_pixel := pop(&stack)
		target.pixels[the_pixel] = new

		i = the_pixel - target.w
		if i >= 0 && target.pixels[i] == old {
			append(&stack, i)
		}

		i = the_pixel + target.w
		if i < len(target.pixels) && target.pixels[i] == old {
			append(&stack, i)
		}

		i = the_pixel + 1
		if i % target.w != 0 && target.pixels[i] == old {
			append(&stack, i)
		}

		i = the_pixel - 1
		if (i + 1) % target.w != 0 && target.pixels[i] == old {
			append(&stack, i)
		}
	}
}

// this turns 0-17 into the 0123456789ABCDEFX sequence
linear_to_ascii_hex :: proc(index: int) -> rune {
	value := index + 48
	if index > 15 {
		value += 24
	} else if index > 9 {
		value += 7
	}
	return cast(rune) value
}

/*
	note: this is super quick and dirty way of saving the data.
	for a proper version of this, you would want to make better
	choices here, such as saving to binary instead of text,
	using compression and omitting unused images
*/

MJSON :: json.Specification.MJSON

unmarshal_json :: proc(data: ^$T, file_name: string, spec := MJSON, allocator := context.allocator, loc := #caller_location) -> bool {
	blob, success := os.read_entire_file(file_name, context.temp_allocator)
	if !success {
		return false
	}

	errno := json.unmarshal(blob, data, spec, allocator)
	if errno != nil {
		return false
	}
	return true
}

marshal_json :: proc(data: $T, file_name: string, spec := MJSON, loc := #caller_location) -> bool {
	options := json.Marshal_Options{
		spec       = spec,
		pretty     = false,
		use_spaces = false,
		spaces     = 0,

		write_uint_as_hex = false,

		mjson_keys_use_quotes     = false,
		mjson_keys_use_equal_sign = true,
		sort_maps_by_key          = true,
		use_enum_names            = false,
	}

	blob, errno := json.marshal(data, options, context.temp_allocator)
	if errno != json.Marshal_Data_Error.None {
		return false
	}

	result := os.write_entire_file(file_name, blob)
	if !result {
		return false
	}
	return true
}
