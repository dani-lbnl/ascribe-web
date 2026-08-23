extends GdUnitTestSuite


func test_header_h1_becomes_font_size_24() -> void:
	var result := MdToBBCode.convert("# Title", "img")
	assert_that(result).is_equal("[font_size=24]Title[/font_size]")


func test_header_h2_becomes_font_size_20() -> void:
	var result := MdToBBCode.convert("## Subtitle", "img")
	assert_that(result).is_equal("[font_size=20]Subtitle[/font_size]")


func test_bold_becomes_b_tag() -> void:
	var result := MdToBBCode.convert("this is **bold** text", "img")
	assert_that(result).is_equal("this is [b]bold[/b] text")


func test_italic_becomes_i_tag() -> void:
	var result := MdToBBCode.convert("this is *italic* text", "img")
	assert_that(result).is_equal("this is [i]italic[/i] text")


func test_image_url_joined_with_base_url() -> void:
	var result := MdToBBCode.convert("![alt](fig1.png)", "https://example.com/base")
	assert_that(result).is_equal("[img]https://example.com/base/fig1.png[/img]")


func test_plain_paragraphs_pass_through() -> void:
	var result := MdToBBCode.convert("Hello world.\n\nSecond paragraph.", "img")
	assert_that(result).is_equal("Hello world.\n\nSecond paragraph.")


func test_bbcode_hostile_input_is_escaped_first() -> void:
	var result := MdToBBCode.convert("literal [bracket] text", "img")
	assert_that(result).is_equal("literal [lb]bracket] text")


func test_bold_inside_escaped_brackets_still_bolds() -> void:
	# Escaping must happen before markdown conversion so real markdown syntax still converts
	# even when the surrounding text has literal brackets.
	var result := MdToBBCode.convert("[note] **bold**", "img")
	assert_that(result).is_equal("[lb]note] [b]bold[/b]")
