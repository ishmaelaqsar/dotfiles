/ kdb-driver.q -- the local q that kdb.el starts loads this file.
/ The process holds one handle to a remote kdb server and evaluates the
/ text that Emacs sends. Results print here, at a wide console, so a remote
/ table renders in full. The last remote result stays in .kdb.last for local
/ work. kdb.el passes the target and the grid settings as environment
/ variables. A file written for kdb.el goes to .kdb.gridDir, with a marker
/ line on stdout that kdb.el watches for. Note: a line holding only "/" opens
/ a block comment in q. Keep text after every comment marker in this file.

system "c 2000 2000";

.kdb.target:`host`port`user`name!getenv each `KDB_HOST`KDB_PORT`KDB_USER`KDB_NAME;
.kdb.gridOn:(enlist "1")~getenv`KDB_GRID;
.kdb.gridDir:$[count d:getenv`KDB_GRID_DIR;d;"/tmp"];
.kdb.gridRows:$[count r:getenv`KDB_GRID_ROWS;"J"$r;5000];
.kdb.gridN:0;

/ Open the handle. Call again after a dropped connection.
.kdb.connect:{[]
  .kdb.h:hopen `$":",":" sv .kdb.target[`host`port`user],enlist "";
  -1 "kdb: connected to ",.kdb.target[`name]," (",.kdb.target[`host],":",.kdb.target[`port],")";
  .kdb.h};

/ Split TEXT into statements, the same rule as run.sh: a blank line or a
/ /-comment line separates statements, and consecutive lines join.
.kdb.split:{[text]
  lines:"\n" vs text;
  sep:{$[0=count t:x where not x=" ";1b;"/"=first t]} each lines;
  idx:where not sep;
  $[count idx;{" " sv x} each lines (0,where 1<@[deltas idx;0;:;1]) cut idx;()]};

/ Unkey T and turn every column csv 0: cannot write, a general list other
/ than strings, into its q text.
.kdb.csvable:{[t]
  flip {$[type[x] within 1 19h;x;(0h=type x) and all 10h=type each x;x;.Q.s1 each x]} each flip 0!t};

/ Write T as CSV, up to .kdb.gridRows rows, and print the line kdb.el
/ watches for. kdb.el reads the file, deletes it, and removes the line.
.kdb.grid:{[t]
  .kdb.gridN+:1;
  path:.kdb.gridDir,"/kdb-grid-",string[.z.i],"-",string[.kdb.gridN],".csv";
  hsym[`$path] 0: csv 0: .kdb.csvable (.kdb.gridRows&count t)#t;
  -1 "kdb-grid: ",path," rows=",string count t;};

/ Evaluate one statement remotely. Print the result, or the error, keep a
/ successful result in .kdb.last, and hand a table to the grid.
.kdb.exec:{[stmt]
  res:@[{(1b;.kdb.h x)};stmt;{(0b;x)}];
  $[first res;
    [.kdb.last:last res;show .kdb.last;if[.kdb.gridOn and .Q.qt .kdb.last;@[.kdb.grid;.kdb.last;{-2 "grid: ",x}]]];
    -2 "ERR: ",last res];};

.kdb.run:{[text] .kdb.exec each .kdb.split text;};

/ Fetch the table and column names over the handle, write them one table
/ per line, "table col col ...", and print the marker line.
.kdb.schema:{
  d:.kdb.h "(tables[])!cols each tables[]";
  path:.kdb.gridDir,"/kdb-schema-",string[.z.i],".txt";
  hsym[`$path] 0: {" " sv string x,y}'[key d;value d];
  -1 "kdb-schema: ",path;};

.kdb.connect[];
@[.kdb.schema;::;{-2 "schema: ",x}];
