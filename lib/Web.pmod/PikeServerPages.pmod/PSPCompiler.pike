constant TYPE_SCRIPTLET = 1;
constant TYPE_DECLARATION = 2;
constant TYPE_INLINE = 3;
constant TYPE_DIRECTIVE = 4;

string document_root = "";

private int includes = 0;

// should this be configurable?
int max_includes = 100;

program compile_string(string code, string realfile)
{
  string psp = parse_psp(code, realfile);

  return compile_string(psp, realfile);
}

array(Block) psp_to_blocks(string file, string realfile)
{
  int file_len = strlen(file);
  int in_tag = 0;
  int sp = 0;
  int old_sp = 0;
  int start_line = 1;
  array contents = ({});

  do 
  {
#ifdef DEBUG
    werror("starting point: %O, len: %O\n", sp, file_len);
#endif
    sp = search(file, "<%", sp);

    if(sp == -1) 
    {
      sp = file_len; 
      if(old_sp!=sp) 
      {
        string s = file[old_sp..sp-1];
        int l = sizeof(s) - sizeof(s-"\n");
        Block b = TextBlock(s, realfile);
        b->start = start_line;
        b->end = (start_line+=l);
        contents += ({b});
      }
    }// no starting point, skip to the end.

    else if(sp >= 0) // have a starting code.
    {
      int end;
      if(in_tag) { error("invalid format: nested tags!\n"); }
      if(old_sp>=0) 
      {
        string s = file[old_sp..sp-1];
        int l = sizeof(s) - sizeof(s-"\n");
        Block b = TextBlock(s, realfile);
        b->start = start_line;
        b->end = (start_line+=l);
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
        Block b = PikeBlock(s, realfile);
        int l = sizeof(s) - sizeof(s-"\n");
        b->start = start_line;
        b->end = (start_line+=l);
        contents += ({b});
        
        sp = end + 1;
        old_sp = sp;
      }
    } 
  }
  while (sp < file_len);

  return contents;
}

string parse_psp(string file, string realname)
{
  // now, let's render some pike!
  string pikescript = "";
  string header = "";

  pikescript+="string|mapping parse(RequestID request){\n";
  pikescript+="String.Buffer out = String.Buffer();\n";
#ifdef ROXEN
  pikescript+="object conf = request->conf;\n";
#endif

  array(Block) contents = psp_to_blocks(file, realname);

  string ps, h;
 
  [ps, h] = render_psp(contents, "", "");

  pikescript += ps;

  header += h;

  pikescript += "return out->get();\n }\n";  

  return header + "\n\n" + pikescript;
}

array render_psp(array(Block) contents, string pikescript, string header)
{
  foreach(contents, object e)
  {
    if(e->get_type() == TYPE_DECLARATION)
      header += e->render();
    else if(e->get_type() == TYPE_DIRECTIVE)
    {
      mixed ren = e->render();
      if(arrayp(ren))
        [pikescript, header] = render_psp(ren, pikescript, header);
    }
    else
      pikescript += e->render();
  }

  return ({pikescript, header});
}


int main(int argc, array(string) argv)
{

  string file = Stdio.read_file(argv[1]);
  if(!file) { werror("input file %s does not exist.\n", argv[1]); return 1;}

  string pikescript = parse_psp(file, argv[1]);

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

class Block(string contents, string filename)
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

  array(Block) | string render();
}

class TextBlock
{
 inherit Block;

 array in = ({"\\", "\"", "\n"});

 array out = ({"\\\\", "\\\"", "\\n"});

 string render()
 {
   return "{\n" + escape_string(contents)  + "}\n";
 }

 
 string escape_string(string c)
 {
    string retval = "";
    int cl = start;
    int atend=0;
    int current=0;
    do
    {
       string line;
       int end = search(c, "\n", current);
       if(end != -1)
       {
         line = c[current..end];
         if(end == (strlen(c) -1))
           atend = 1;
         else current = end + 1;
       }
       if(end == -1)
       {
         line = c[current..end];
         atend = 1;
       }
       line = replace(line, in, out);
       if(strlen(line))
       {
         retval+=("#line " + cl + " \"" + filename + "\"\n out->add(\"" + line + "\");\n");
         cl++;
       } 
    } while(!atend);

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
    if(has_prefix(contents, "<%@")) return TYPE_DIRECTIVE;
    else return TYPE_SCRIPTLET;
  }

  array(Block) | string render()
  {
    if(has_prefix(contents, "<%!"))
    {
      string expr = contents[3..strlen(contents)-3];
      return("// "+ start + " - " + end + "\n#line " + start + " \"" + filename + "\"\n" + expr);
    }

    else if(has_prefix(contents, "<%@"))
    {
      string expr = contents[3..strlen(contents)-3];
      return parse_directive(expr);
    }

    else if(has_prefix(contents, "<%="))
    {
      string expr = String.trim_all_whites(contents[3..strlen(contents)-3]);
      return("// "+ start + " - " + end + "\n#line " + start + " \"" + filename + "\"\nout->add((string)(" + expr + "));");
    }

    else
    {
      string expr = String.trim_all_whites(contents[2..strlen(contents)-3]);
      return "// "+ start + " - " + end + "\n#line " + start + " \"" + filename + "\"\n" + expr + "\n";
    }
  }

 string|array(Block) parse_directive(string exp)
 {
   exp = String.trim_all_whites(exp);
 
   if(search(exp, "\n")!=-1)
     throw(Error.Generic("PSP format error: invalid directive format.\n"));
 
   // format of a directive is: keyword option="value" ...
 
   string keyword;
 
   int r = sscanf(exp, "%[A-Za-z0-9] %s", keyword, exp);
 
   if(r!=2) 
     throw(Error.Generic("PSP format error: invalid directive format.\n"));
 
 werror("keyword %O\n", keyword);
 
   switch(keyword)
   {
     case "include":
       return process_include(exp);
       break;
 
     default:
       throw(Error.Generic("PSP format error: unknown directive " + keyword + ".\n"));
 
   }
 }

 // we don't handle absolute includes yet.
 array(Block) process_include(string exp)
 {
   string file;
   string contents;

   if(includes > max_includes) throw(Error.Generic("PSP Error: too many includes, possible recursion!\n")); 

   includes++;

   int r = sscanf(exp, "%*sfile=\"%s\"%*s", file);
 
   if(r != 3) 
     throw(Error.Generic("PSP format error: unknown include format.\n"));

   string realfile;

   if(file[0] = '/')
   {
     realfile = Stdio.append_path(document_root, (file/"/" - ({""})) * "/");
   }
   else 
   {
     realfile = file; 
   }
   contents = Stdio.read_file(realfile);
 
 werror("contents: %O\n", contents);
 
   if(contents)
   {
     array x = psp_to_blocks(contents, file);
     werror("blocks: %O\n", x);
     return x;
   }

  }
}

