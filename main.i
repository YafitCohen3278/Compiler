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

//  writeLine(s)
//    Writes a single line to the output .asm file.
//    Parameters: s - the string to write

func writeLine(s)
{
    write, outFile, format="%s\n", s;
}

//  dispatch(w1, w2, w3)
//    Identifies the VM command and writes the appropriate output.
//    Parameters:
//      w1 - command name (e.g. "push", "add", "eq")
//      w2 - segment name for push/pop (e.g. "static", "local")
//      w3 - index for push/pop (e.g. "0", "4")
func dispatch(w1, w2, w3)
{
    extern logicCounter;

    // --- Arithmetic commands ---
    if (w1 == "add") {
        writeLine, "command: add";
        return;
    }
    if (w1 == "sub") {
        writeLine, "command: sub";
        return;
    }
    if (w1 == "neg") {
        writeLine, "command: neg";
        return;
    }

    // --- Logical commands: increment counter then print ---
    if (w1 == "eq") {
        logicCounter++;
        writeLine, "command: eq";
        writeLine, "counter: " + swrite(format="%d", logicCounter);
        return;
    }
    if (w1 == "gt") {
        logicCounter++;
        writeLine, "command: gt";
        writeLine, "counter: " + swrite(format="%d", logicCounter);
        return;
    }
    if (w1 == "lt") {
        logicCounter++;
        writeLine, "command: lt";
        writeLine, "counter: " + swrite(format="%d", logicCounter);
        return;
    }

    // --- Memory access commands ---
    if (w1 == "push") {
        writeLine, "command: push segment " + w2 + " index " + w3;
        return;
    }
    if (w1 == "pop") {
        writeLine, "command: pop segment " + w2 + " index " + w3;
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

    // --- Extract folder name for output filename ---
    lastSlash = 0;
    n = strlen(dirPath);
    for (k = 1; k <= n; k++) {
        c = strpart(dirPath, k:k);
        if (c == "/" || c == "\\") lastSlash = k;
    }
    folderName = strpart(dirPath, lastSlash+1 : n);  // e.g. "TARGIL0"

    asmName = folderName + ".asm";                   // e.g. "TARGIL0.asm"
    asmPath = dirPath + "/" + asmName;

    // --- Scan directory for all .vm files ---
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

    // --- Process each .vm file ---
    for (i = 1; i <= nvm; i++) {
        processVMFile, vmFiles(i);
    }

    // --- Close output file and print final message ---
    close, outFile;
    write, format="Output file is ready: %s\n", asmName;
}

main;
