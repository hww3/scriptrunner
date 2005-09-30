constant TYPE_SCRIPTLET = 1;
constant TYPE_DECLARATION = 2;
constant TYPE_INLINE = 3;

program compile_string(string code, string realfile)
{
  string psp = parse_psp(code);

  return compile_string(psp, realfile);
}

string parse_psp(string file)
{
  int file_len = strlen(file);
  int in_tag = 0;
  int sp = 0;
  int old_sp = -1;
  int start_line = 0;
  array contents = ({});

  do 
  {
#ifdef DEBUG
    werror("starting point: %O, len: %O\n", sp, file_len);
#endif
    sp = search(file, "<%", sp);

    if(sp == -1) {sp = file_len; }// no starting point, skip to the end.
    else if(sp >= 0) // have a starting code.
    {
      int end;
      if(in_tag) { error("invalid format: nested tags!\n"); }
      if(old_sp>=0) {
        string s = file[old_sp..sp-1];
        int l = sizeof(s/"\n");
        Block b = TextBlock(s);
        b->start = start_line;
        b->end = (start_line ++);
        contents += ({b});
      }
      if((sp == 0) || (sp > 0 && file[sp-1] != '<'))
      {
        in_tag = 1;
        end = find_end(file, sp);
      }
      else { sp = sp + 2; continue; } // the start was escaped.

      if(end == -1) error("invalid format: missing end tag.\n");

      else 
      {
        in_tag = 0;
        string s = file[sp..end];
        int l = sizeof(s/"\n");
        Block b = PikeBlock(s);
        b->start = start_line;
        b->end = (start_line ++);
        contents += ({b});
        
        sp = end + 1;
        old_sp = sp;
      }
    } 
  }
  while (sp < file_len);

  // now, let's render some pike!
  string pikescript = "";
  string header = "";

  pikescript+="string|mapping parse(RequestID request){\n";
  pikescript+="String.Buffer out = String.Buffer();\n";
  pikescript+="object conf = request->conf;\n";

  foreach(contents, object e)
  {
    if(e->get_type() == TYPE_DECLARATION)
      header += e->render();
    else
      pikescript += e->render();
  }

  pikescript += "return out->get();\n }\n";  

  return header + "\n\n" + pikescript;
}

int main(int argc, array(string) argv)
{

  string file = Stdio.read_file(argv[1]);
  if(!file) { werror("input file %s does not exist.\n", argv[1]); return 1;}

  string pikescript = parse_psp(file);

  write(pikescript);

  return 0;
}

int find_end(string f, int start)
{
  int ret;

  do
  {
    int p = search(f, "%>", start);
#ifdef DEBUG
werror("p: %O", p);
#endif
    if(p == -1) return 0;
    else if(f[p-1] == '%') {
#ifdef DEBUG
werror("escaped!\n"); 
#endif
start = start + 2; continue; } // (escaped!)
    else { 
#ifdef DEBUG
werror("got the end!\n"); 
#endif
ret = p + 1;}
  } while(!ret);
#ifdef DEBUG
werror("returning: %O\n", ret);
#endif
  return ret;
}

class Block(string contents)
{
  int start;
  int end;

  int get_type()
  {
    return 0;
  }

  string _sprintf(mixed type)
  {
    return "Block(" + contents + ")";
  }

  string render();
}

class TextBlock
{
 inherit Block;

 array in = ({"\\", "\""});

 array out = ({"\\\\", "\\\""});

 string render()
 {
   return "{\n" + escape_string(contents)  + "}\n";
 }

 
 string escape_string(string c)
 {
    string retval = "";
    int cl = start;
    foreach(c/"\n", string line)
    {
       
       line = replace(line, in, out);
       retval+=("#line " + cl + "\n out->add(\"" + line + "\\n\");\n");
       cl++;
      
    }

    return retval;

 }

}

class PikeBlock
{
  inherit Block;

  int get_type()
  {
    if(has_prefix(contents, "<%=")) return TYPE_INLINE;
    if(has_prefix(contents, "<%!")) return TYPE_DECLARATION;
    else return TYPE_SCRIPTLET;
  }

  string render()
  {
    if(has_prefix(contents, "<%!"))
    {
      string expr = contents[3..strlen(contents)-3];
      return("#line " + start + "\n" + expr);
    }

    else if(has_prefix(contents, "<%="))
    {
      string expr = String.trim_all_whites(contents[3..strlen(contents)-3]);
      return("#line " + start + "\nout->add((string)(" + expr + "));");
    }

    else
    {
      string expr = String.trim_all_whites(contents[2..strlen(contents)-3]);
      return "#line " + start + "\n" + expr + "\n";
    }
  }
}
