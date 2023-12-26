package soggy

import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

Winfo :: struct{
	hi, lo: Program_layer,

	/* set once */
	window_title: cstring,

	hi_init_size: [2]i32,
	lo_scale: i32,
	hi_minimum_size: [2]i32,

	draw_on_top: enum{hi, lo},

	/* read only */
	window_size: [2]i32,
	window_size_changed: bool,

	_lo_minimum_size: [2]i32,

	_window_handle: glfw.WindowHandle,
	_shader_program: u32,

	_vertex_buffer_o, _vertex_array_o, _element_buffer_o: u32,
	_lo_tex_o, _hi_tex_o: u32
}

start :: proc(using winfo: ^Winfo) -> (started: bool) {
	if !bool(glfw.Init()) {
		fmt.eprintln("GLFW has failed to init")
		return false
	}

	{/* setup and open window */
//		glfw.WindowHint(glfw.MAXIMIZED, 1)
		glfw.WindowHint(glfw.RESIZABLE, 1)
		_window_handle = glfw.CreateWindow(hi_init_size.x, hi_init_size.y, window_title, nil, nil)
		if _window_handle == nil {
			fmt.eprintln("GLFW has failed to create a window")
			return false
		}
		glfw.MakeContextCurrent(_window_handle)

		glfw.SetFramebufferSizeCallback(_window_handle, window_size_changed_proc)
		glfw.SetWindowSizeLimits(_window_handle, hi_minimum_size.x, hi_minimum_size.y, glfw.DONT_CARE, glfw.DONT_CARE)
		window_size.x, window_size.y = glfw.GetFramebufferSize(_window_handle)
		gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
	}

	{ /* compile and link shaders */
		success: i32
		shader_had_error: bool
		log_backing: [512]u8
		log := cast([^]u8) &log_backing
		vertex_shader_source := #load("./vertex.glsl", cstring)
		fragment_shader_source := #load("./fragment.glsl", cstring)
		/* compile vertex shader */
		vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
		defer gl.DeleteShader(vertex_shader)
		gl.ShaderSource(vertex_shader, 1, &vertex_shader_source, nil)
		gl.CompileShader(vertex_shader)
		if gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success); !bool(success) {
			gl.GetShaderInfoLog(vertex_shader, len(log_backing), nil, log)
			fmt.eprintln("vertex shader error:", cstring(log) )
			shader_had_error = true
		}
		/* compile fragment shader */
		fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
		defer gl.DeleteShader(fragment_shader)
		gl.ShaderSource(fragment_shader, 1, &fragment_shader_source, nil)
		gl.CompileShader(fragment_shader)
		if gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success); !bool(success) {
			gl.GetShaderInfoLog(fragment_shader, len(log_backing), nil, log)
			fmt.eprintln("fragment shader error:", cstring(log) )
			shader_had_error = true
		}
		/* link fragment shader */
		_shader_program = gl.CreateProgram()
		gl.AttachShader(_shader_program, vertex_shader)
		gl.AttachShader(_shader_program, fragment_shader)
		gl.LinkProgram(_shader_program)
		if gl.GetShaderiv(_shader_program, gl.LINK_STATUS, &success); !bool(success) {
			gl.GetShaderInfoLog(_shader_program, len(log_backing), nil, log)
			fmt.eprintln("shader linking error:", cstring(log) )
			shader_had_error = true
		}
		if shader_had_error do return false
	}

	{ /* do some frankly insane triangle definition stuff */
		vertices := [?]f32 {
			/* triangle vertices */  /* texture coords */
			-2.0, -1.0, 0.0,         -0.5, 0.0,  // bottom left
			 2.0, -1.0, 0.0,         1.5, 0.0,   // bottom right
			 0.0,  3.0, 0.0,         0.5,  2,    // top
		}
		indices := [?]u32 {
			0, 1, 2, // first
			0, 1, 2  // second
		}
		gl.GenVertexArrays(1, &_vertex_array_o) /* this has info about how to read the buffer */
		gl.GenBuffers(1, &_vertex_buffer_o)     /* this has the actual data */
		gl.GenBuffers(1, &_element_buffer_o)    /* this is a decoupling layer for the actual data for re-using vertices */

		gl.BindVertexArray(_vertex_array_o) /* global state indicators */
		gl.BindBuffer(gl.ARRAY_BUFFER, _vertex_buffer_o)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, _element_buffer_o)

		gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices[0], gl.STATIC_DRAW)
		gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices[0], gl.STATIC_DRAW)

		gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 5*size_of(f32), uintptr(0)) /* give info about how to read the buffer */
		gl.EnableVertexAttribArray(0) /* this zero is the same 0 as the first 0 in the call above */
		gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 5*size_of(f32), uintptr(3*size_of(f32)))
		gl.EnableVertexAttribArray(1)
//		gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	}

	{/* initialize main program layers */
		lo.size = window_size/lo_scale
		hi.size = window_size
//		fmt.println("sizes of texes", lo.size, hi.size)
		lo.data = make([dynamic][4]byte, area(lo.size))
		hi.data = make([dynamic][4]byte, area(hi.size))
		lo.tex = lo.data[:]
		hi.tex = hi.data[:]
	}

	{/* show the main program layers to the gpu */
		gl.GenTextures(1, &_lo_tex_o)
		gl.BindTexture(gl.TEXTURE_2D, _lo_tex_o)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST); gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, expand_values(lo.size), 0, gl.RGBA, gl.UNSIGNED_BYTE, &lo.tex[0])

		gl.GenTextures(1, &_hi_tex_o)
		gl.BindTexture(gl.TEXTURE_2D, _hi_tex_o)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST); gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, expand_values(hi.size), 0, gl.RGBA, gl.UNSIGNED_BYTE, &hi.tex[0])

		gl.UseProgram(_shader_program)
		switch draw_on_top {
		case .hi:
			gl.Uniform1i(gl.GetUniformLocation(_shader_program, "top_texture"), 1)
			gl.Uniform1i(gl.GetUniformLocation(_shader_program, "bot_texture"), 0)
		case .lo:
			gl.Uniform1i(gl.GetUniformLocation(_shader_program, "top_texture"), 0)
			gl.Uniform1i(gl.GetUniformLocation(_shader_program, "bot_texture"), 1)
		}
	}
	return true;
}

loop :: proc(using winfo: ^Winfo) -> (should_continue: bool) {
	gl.ClearColor(0.5, 0.5, 0.5, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, _lo_tex_o)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, expand_values(lo.size), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(lo.tex))
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, _hi_tex_o)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, expand_values(hi.size), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(hi.tex))

	gl.UseProgram(_shader_program)
	gl.BindVertexArray(_vertex_array_o)
	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

	glfw.SwapBuffers(_window_handle)

	glfw.PollEvents()
	{ /* if window size changes */
		new_window_size: [2]i32
		new_window_size.x, new_window_size.y = glfw.GetFramebufferSize(_window_handle)
		window_size_changed = false
		if new_window_size != window_size {
			window_size_changed = true
			window_size = new_window_size
			lo.size = vec_max(window_size/lo_scale, _lo_minimum_size)
			hi.size = vec_max(window_size, hi_minimum_size)

			if area(lo.size) > len(lo.data) || area(hi.size) > len(hi.data) {
				resize(&lo.data, area(lo.size))
				resize(&hi.data, area(hi.size))
				lo.tex = lo.data[:]
				hi.tex = hi.data[:]
			} else {
				lo.tex = lo.data[0:area(lo.size)]
				hi.tex = hi.data[0:area(hi.size)]
			}
		}
	}

	return !glfw.WindowShouldClose(_window_handle)
}

exit :: proc(using winfo: ^Winfo) {
	{/* de-initialize main program layers */
		delete(lo.data)
		delete(hi.data)
	}
	{/* undo some frankly insane triangle definition stuff */
		gl.DeleteVertexArrays(1, &_vertex_array_o)
		gl.DeleteBuffers(1, &_vertex_buffer_o)
		gl.DeleteBuffers(1, &_element_buffer_o)
	}
	gl.DeleteProgram(_shader_program)
	glfw.DestroyWindow(_window_handle)
	glfw.Terminate()
}

@(private)
window_size_changed_proc :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}
