//
// display a list of available fonts
// when a font is selected from the list, it's name is rendered in that 
// font and returned as a png file.

mixed parse(object id)
{
  string retval = "";

  if(id->variables->font)
  {
    object fnt = Image.Fonts.open_font(id->variables->font,
                                     72, UNDEFINED, 0);
    object i = fnt->write("This is " + id->variables->font + ".");

    return ([ "type": "image/png", "data": Image.PNG.encode(i) ]);
  }


  mapping f = Image.Fonts.list_fonts();

  foreach(f; string name; mixed blah)
  {
    retval  = retval + "<a href=\"?font=" + name + "\">" + name + "</a><br>\n";
  }
  return retval;
}
