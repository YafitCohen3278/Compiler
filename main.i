//  VM Translator - Written in Yorick
//
//  Description:
//    Reads all .vm files from a given directory and translates
//    them into a single .asm output file.
//
//  Usage:
//    yorick -batch main.i <directory_path>
//    Example: yorick -batch main.i C:/Users/user/COMPILER/TARGIL0
//
//  Output:
//    A single .asm file named after the input directory.
//    Example: TARGIL0.asm

// outFile      - file handle for the output .asm file
// currentVM    - name of the current .vm file (without extension)
// logicCounter - counts logical commands per file, resets each file
local outFile;
local currentVM;
local logicCounter;
local callCounter;

//  writeLine(s)
//    Writes a single line to the output .asm file.
//    Parameters: s - the string to write

func writeLine(s)
{
    write, outFile, format="%s\n", s;
}

func vmParseInt(s)
{
    v = 0;
    ns = strlen(s);
    for (j = 1; j <= ns; j++) {
        c = strpart(s, j:j);
        for (d = 0; d <= 9; d++) {
            if (c == swrite(format="%d", d)) {
                v = v * 10 + d;
                break;
            }
        }
    }
    return v;
}

//  dispatch(w1, w2, w3)
//    Identifies the VM command and writes the appropriate output.
//    Parameters:
//      w1 - command name (e.g. "push", "add", "eq")
//      w2 - segment name for push/pop (e.g. "static", "local")
//      w3 - index for push/pop (e.g. "0", "4")
func dispatch(w1, w2, w3)
{
    extern logicCounter, currentVM, callCounter;

    if (w1 == "add") {
        writeLine("@SP"); writeLine("AM=M-1"); writeLine("D=M");
        writeLine("A=A-1"); writeLine("M=M+D");
        return;
    }

    if (w1 == "sub") {
        writeLine("@SP"); writeLine("AM=M-1"); writeLine("D=M");
        writeLine("A=A-1"); writeLine("M=M-D");
        return;
    }

    if (w1 == "neg") {
        writeLine("@SP"); writeLine("A=M-1"); writeLine("M=-M");
        return;
    }

    if (w1 == "eq" || w1 == "gt" || w1 == "lt") {
        logicCounter++;

        labelTrue = "TRUE_" + swrite(format="%d", logicCounter);
        labelEnd  = "END_"  + swrite(format="%d", logicCounter);

        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");
        writeLine("A=A-1");
        writeLine("D=M-D");

        writeLine("@" + labelTrue);

        if (w1 == "eq") writeLine("D;JEQ");
        if (w1 == "gt") writeLine("D;JGT");
        if (w1 == "lt") writeLine("D;JLT");

        writeLine("@SP");
        writeLine("A=M-1");
        writeLine("M=0");

        writeLine("@" + labelEnd);
        writeLine("0;JMP");

        writeLine("(" + labelTrue + ")");
        writeLine("@SP");
        writeLine("A=M-1");
        writeLine("M=-1");

        writeLine("(" + labelEnd + ")");
        return;
    }

    if (w1 == "and") {
        writeLine("@SP");
        writeLine("AM=M-1");   // SP--, A=SP
        writeLine("D=M");      // D = y
        writeLine("A=A-1");    // A = SP-1 (x)
        writeLine("M=M&D");    // x = x & y
        return;
    }
    
    if (w1 == "or") {
        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");
        writeLine("A=A-1");
        writeLine("M=M|D");    // x = x | y
        return;
    }
    
    if (w1 == "not") {
        writeLine("@SP");
        writeLine("A=M-1");    // top element
        writeLine("M=!M");     // bitwise NOT
        return;
    }

    if (w1 == "push" && w2 == "constant") {
        writeLine("@" + w3);
        writeLine("D=A");
        writeLine("@SP");
        writeLine("A=M");
        writeLine("M=D");
        writeLine("@SP");
        writeLine("M=M+1");
        return;
    }

    base = "";
    if (w2 == "local") base = "LCL";
    if (w2 == "argument") base = "ARG";
    if (w2 == "this") base = "THIS";
    if (w2 == "that") base = "THAT";

    if (w1 == "push" && base != "") {
        writeLine("@" + w3);
        writeLine("D=A");
        writeLine("@" + base);
        writeLine("A=M+D");
        writeLine("D=M");

        writeLine("@SP");
        writeLine("A=M");
        writeLine("M=D");
        writeLine("@SP");
        writeLine("M=M+1");
        return;
    }

    if (w1 == "pop" && base != "") {
        writeLine("@" + w3);
        writeLine("D=A");
        writeLine("@" + base);
        writeLine("D=M+D");

        writeLine("@R13");
        writeLine("M=D");

        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");

        writeLine("@R13");
        writeLine("A=M");
        writeLine("M=D");
        return;
    }

    if (w1 == "push" && w2 == "temp") {
        addr = swrite(format="%d", 5 + vmParseInt(w3));
        writeLine("@" + addr);
        writeLine("D=M");

        writeLine("@SP");
        writeLine("A=M");
        writeLine("M=D");
        writeLine("@SP");
        writeLine("M=M+1");
        return;
    }

    if (w1 == "pop" && w2 == "temp") {
        addr = swrite(format="%d", 5 + vmParseInt(w3));

        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");

        writeLine("@" + addr);
        writeLine("M=D");
        return;
    }

    if (w1 == "push" && w2 == "pointer") {
        if (w3 == "0") writeLine("@THIS");
        if (w3 == "1") writeLine("@THAT");

        writeLine("D=M");
        writeLine("@SP");
        writeLine("A=M");
        writeLine("M=D");
        writeLine("@SP");
        writeLine("M=M+1");
        return;
    }

    if (w1 == "pop" && w2 == "pointer") {
        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");

        if (w3 == "0") writeLine("@THIS");
        if (w3 == "1") writeLine("@THAT");

        writeLine("M=D");
        return;
    }

    if (w1 == "push" && w2 == "static") {
        name = currentVM + "." + w3;

        writeLine("@" + name);
        writeLine("D=M");
        writeLine("@SP");
        writeLine("A=M");
        writeLine("M=D");
        writeLine("@SP");
        writeLine("M=M+1");
        return;
    }

    if (w1 == "pop" && w2 == "static") {
        name = currentVM + "." + w3;

        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");

        writeLine("@" + name);
        writeLine("M=D");
        return;
    }

    if (w1 == "function") {
        fname = w2;
        k = vmParseInt(w3);

        writeLine("(" + fname + ")");

        for (i = 1; i <= k; i++) {
            writeLine("@0");
            writeLine("D=A");
            writeLine("@SP");
            writeLine("A=M");
            writeLine("M=D");
            writeLine("@SP");
            writeLine("M=M+1");
        }
        return;
    }

    if (w1 == "goto") {
        label = currentVM + "." + w2;
        writeLine("@" + label);
        writeLine("0;JMP");
        return; if (w1 == "if-goto") {
        label = currentVM + "." + w2;
    
        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");
    
        writeLine("@" + label);
        writeLine("D;JNE");
    
        return;
     }
    }

    if (w1 == "if-goto") {
        label = currentVM + "." + w2;

        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");

        writeLine("@" + label);
        writeLine("D;JNE");
        return;
    }

    if (w1 == "label") {
        label = currentVM + "." + w2;
        writeLine("(" + label + ")");
        return;
    }

    if (w1 == "call") {
        callCounter++;

        fname = w2;
        n = vmParseInt(w3);
        ret = fname + "$ret." + swrite(format="%d", callCounter);

        // push return address
        writeLine("@" + ret);
        writeLine("D=A");
        writeLine("@SP");
        writeLine("A=M");
        writeLine("M=D");
        writeLine("@SP");
        writeLine("M=M+1");

        // push LCL ARG THIS THAT
        writeLine("@LCL"); writeLine("D=M");
        writeLine("@SP"); writeLine("A=M"); writeLine("M=D");
        writeLine("@SP"); writeLine("M=M+1");

        writeLine("@ARG"); writeLine("D=M");
        writeLine("@SP"); writeLine("A=M"); writeLine("M=D");
        writeLine("@SP"); writeLine("M=M+1");

        writeLine("@THIS"); writeLine("D=M");
        writeLine("@SP"); writeLine("A=M"); writeLine("M=D");
        writeLine("@SP"); writeLine("M=M+1");

        writeLine("@THAT"); writeLine("D=M");
        writeLine("@SP"); writeLine("A=M"); writeLine("M=D");
        writeLine("@SP"); writeLine("M=M+1");

        // ARG = SP - n - 5
        writeLine("@SP");
        writeLine("D=M");
        writeLine("@" + swrite(format="%d", n + 5));
        writeLine("D=D-A");
        writeLine("@ARG");
        writeLine("M=D");

        // LCL = SP
        writeLine("@SP");
        writeLine("D=M");
        writeLine("@LCL");
        writeLine("M=D");

        // goto function
        writeLine("@" + fname);
        writeLine("0;JMP");

        writeLine("(" + ret + ")");
        return;
    }

    if (w1 == "return") {

        writeLine("@LCL");
        writeLine("D=M");
        writeLine("@R13");
        writeLine("M=D");

        writeLine("@5");
        writeLine("A=D-A");
        writeLine("D=M");
        writeLine("@R14");
        writeLine("M=D");

        writeLine("@SP");
        writeLine("AM=M-1");
        writeLine("D=M");
        writeLine("@ARG");
        writeLine("A=M");
        writeLine("M=D");

        writeLine("@ARG");
        writeLine("D=M+1");
        writeLine("@SP");
        writeLine("M=D");

        writeLine("@R13");
        writeLine("AM=M-1");
        writeLine("D=M");
        writeLine("@THAT");
        writeLine("M=D");

        writeLine("@R13");
        writeLine("AM=M-1");
        writeLine("D=M");
        writeLine("@THIS");
        writeLine("M=D");

        writeLine("@R13");
        writeLine("AM=M-1");
        writeLine("D=M");
        writeLine("@ARG");
        writeLine("M=D");

        writeLine("@R13");
        writeLine("AM=M-1");
        writeLine("D=M");
        writeLine("@LCL");
        writeLine("M=D");

        writeLine("@R14");
        writeLine("A=M");
        writeLine("0;JMP");

        return;
    }
}

//  processVMFile(filepath)
//    Processes a single .vm input file line by line.
//    Parameters: filepath - full path to the .vm file
func processVMFile(filepath)
{
    extern outFile, currentVM, logicCounter;

    // --- Extract filename from full path ---
    lastSlash = 0;
    n = strlen(filepath);
    for (k = 1; k <= n; k++) {
        c = strpart(filepath, k:k);
        if (c == "/" || c == "\\") lastSlash = k;
    }
    basename  = strpart(filepath, lastSlash+1 : n);  // e.g. "InputA.vm"
    currentVM = strpart(basename, 1 : strlen(basename)-3);  // e.g. "InputA"

    // --- Reset logical counter for this file ---
    logicCounter = 0;

    // --- Read all lines at once ---
    lines  = rdfile(filepath);
    nlines = numberof(lines);

    for (li = 1; li <= nlines; li++) {
        line = strtrim(lines(li));

        // Skip empty lines
        if (strlen(line) == 0) continue;

        // Skip full comment lines
        if (strpart(line, 1:2) == "//") continue;

        // Strip inline comments
        ci = strfind("//", line);
        if (ci(1) >= 0) line = strtrim(strpart(line, 1:ci(1)));
        if (strlen(line) == 0) continue;

        // --- Split line into up to 3 words ---
        w1 = ""; w2 = ""; w3 = "";
        llen = strlen(line);

        p1 = strfind(" ", line);
        if (p1(1) < 0) {
            // Single word command (e.g. "add", "neg")
            w1 = line;
        } else {
            w1   = strpart(line, 1 : p1(1));
            rest = strtrim(strpart(line, p1(2) : llen));
            if (strlen(rest) > 0) {
                p2 = strfind(" ", rest);
                if (p2(1) < 0) {
                    // Two word command
                    w2 = rest;
                } else {
                    // Three word command (e.g. "push static 0")
                    w2 = strpart(rest, 1 : p2(1));
                    w3 = strtrim(strpart(rest, p2(2) : strlen(rest)));
                }
            }
        }

        if (strlen(w1) == 0) continue;

        // --- Call dispatcher with the parsed words ---
        dispatch, w1, w2, w3;
    }

    // --- Print end of file message to console ---
    write, format="End of input file: %s.vm\n", currentVM;
}

//  main()
//    Entry point of the program.
//    Reads directory path from command line, finds all .vm
//    files, and processes them into a single .asm output file.
func main(void)
{
    extern outFile;
    logicCounter = 0;
    callCounter = 0;

    // --- Read directory path from command line argument ---
    // Usage: yorick -batch main.i C:/Users/user/COMPILER/TARGIL0
    argv  = get_argv();
    nargs = numberof(argv);
    if (nargs < 2) {
        write, "Error: missing directory path argument";
        write, "Usage: yorick -batch main.i <directory_path>";
        return;
    }
    dirPath = argv(2);

    // --- Remove trailing slash if present ---
    dlen = strlen(dirPath);
    lastChar = strpart(dirPath, dlen:dlen);
    if (lastChar == "/" || lastChar == "\\") {
        dirPath = strpart(dirPath, 1:dlen-1);
    }
    nd = "";
    n = strlen(dirPath);
    for (k = 1; k <= n; k++) {
        c = strpart(dirPath, k:k);
        if (c == "\\") c = "/";
        nd = nd + c;
    }
    dirPath = nd;

    // --- Extract folder name for output filename ---
    lastSlash = 0;
    n = strlen(dirPath);
    for (k = 1; k <= n; k++) {
        c = strpart(dirPath, k:k);
        if (c == "/" || c == "\\") lastSlash = k;
    }
    folderName = strpart(dirPath, lastSlash+1 : n);  // e.g. "TARGIL0"

    asmName = folderName + ".asm";                   // e.g. "TARGIL0.asm"
    asmPath = dirPath + "/" + asmName;    // --- Scan directory for all .vm files ---
    allFiles = lsdir(dirPath);
    vmFiles  = array(string, numberof(allFiles));
    nvm = 0;
    for (f = 1; f <= numberof(allFiles); f++) {
        fname = allFiles(f);
        flen  = strlen(fname);
        if (flen > 3 && strpart(fname, flen-2:flen) == ".vm") {
            nvm++;
            vmFiles(nvm) = dirPath + "/" + fname;
        }
    }

    // --- Check that .vm files were found ---
    if (nvm == 0) {
        write, format="No .vm files found in %s\n", dirPath;
        return;
    }

    // --- Open output file for writing ---
    remove, asmPath;
    outFile = open(asmPath, "w");

    // =========================
    // BOOTSTRAP (IMPORTANT)
    // =========================
    if (nvm > 1) {

        // SP = 256
        writeLine("@256");
        writeLine("D=A");
        writeLine("@SP");
        writeLine("M=D");

        // call Sys.init 0
        dispatch, "call", "Sys.init", "0";
    }
    
    // --- Process each .vm file ---
    for (i = 1; i <= nvm; i++) {
        processVMFile, vmFiles(i);
    }

    // --- Close output file and print final message ---
    close, outFile;
    write, format="Output file is ready: %s\n", asmName;
}

main;
