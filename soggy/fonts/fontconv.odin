package fontthing

import "core:fmt"
import "core:slice"
import "core:image/png"
import "core:bytes"
import "core:os"
println :: fmt.println
printf :: fmt.printf

font_name :: "libertinus_math_regular"
font_size :: "_20"

main :: proc() {
	img: struct{
		size: [2]i32,
		data: [][4]byte,
	}
	{
		image_name :: font_name + font_size + ".png"
		oimg, err := png.load(image_name)
		if err != nil {
			fmt.eprintln("fontthing: file", image_name, "not found")
			fmt.eprintln(err)
			return
		}
		defer png.destroy(oimg)
		if oimg.channels != 4 {
			fmt.eprintln("fontthing: wrong amount of channels in", image_name)
			return
		}
		if oimg.depth != 8 {
			fmt.eprintln("fontthing: wrong pixel depth in", image_name)
			return
		}
		img.size.x = i32(oimg.width)
		img.size.y = i32(oimg.height)
		img.data = make([][4]byte, img.size.x*img.size.y)
		buf := slice.reinterpret([]byte, img.data[:])
		copy(buf, bytes.buffer_to_bytes(&oimg.pixels))
	}

	Table_entry :: struct {
		char: rune,
		place: int,
		size: [2]i32,
		offset: [2]i32,
		advance: i32
	}
	vaim_header_size :: 4 + 2 + 2 + 8 + 8
	vaim_header := make([dynamic]byte, vaim_header_size)
	vaim_table := make([dynamic]Table_entry)
	vaim_body := make([dynamic]byte)
	copy(vaim_header[:], []byte{'v', 'a', 'i', 'm', 1,0 /* vaim version */, 1,0 /* bytes per pixel */})
	defer {
		table_size := cast(^int) &vaim_header[8]
		body_size := cast(^int) &vaim_header[16]
		table_size ^= len(vaim_table)
		body_size ^= len(vaim_body)
		append(&vaim_header, ..slice.reinterpret([]byte, vaim_table[:])[:])
		append(&vaim_header, ..vaim_body[:])
		os.write_entire_file(font_name + font_size + ".vaim", vaim_header[:], false)
		delete(vaim_header)
		delete(vaim_table)
		delete(vaim_body)
	}

	age := slice.reinterpret([]f32, #load(font_name + font_size + ".agefnt"))
	max_height := i32(age[2])
	printf("max height: %v, %v\n", max_height, img.size.y)
	for i := 3; i < len(age); i += 8 {
		using table_entry: Table_entry
		char = transmute(rune) age[i]
		place = len(vaim_body)
		img_place := [2]i32{i32(age[i + 1]), i32(age[i + 2])}
		size = [2]i32{i32(age[i + 3]), i32(age[i + 4])} - img_place
		offset = [2]i32{i32(age[i + 5]), max_height - i32(age[i + 6])}
		advance = i32(age[i + 7])
		append(&vaim_table, table_entry)

		printf("%v\n", transmute(rune) age[i])
		printf("place: %v\n", place)
		printf("size: %v\n", size)
		printf("offset: %v\n", offset)
		printf("advance: %v\n", advance)

		resize(&vaim_body, place + int(size.x*size.y))
		j := 0
		for y in img_place.y..<img_place.y + size.y {
			for x in img_place.x..<img_place.x + size.x {
				i := x + img.size.x*y
				vaim_body[place + j] = img.data[i].a
				j += 1
				if y == img_place.y + offset.y do printf("#")
				else if img.data[i].a >= 125 do printf("!")
				else do printf(".")
			}
			println()
		}
	}

}
