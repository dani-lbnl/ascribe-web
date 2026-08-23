from ascribe_bundle.story import parse_story

MD = """@specimen vol0
# Intro

Some text with ![a figure](fig1.png).

---

Second page, no pin.
"""


def test_parse_pages_and_pins():
    pages, images = parse_story(MD)
    assert len(pages) == 2
    assert pages[0]["specimen"] == "vol0"
    assert "# Intro" in pages[0]["text"]
    assert "@specimen" not in pages[0]["text"]
    assert pages[1]["specimen"] is None
    assert images == ["fig1.png"]
