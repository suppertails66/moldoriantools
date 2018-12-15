#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TThingyTable.h"
#include "exception/TGenericException.h"
#include <string>
#include <fstream>
#include <iostream>

using namespace std;
using namespace BlackT;

const static int outRomSize = 0x100000;

int main(int argc, char* argv[]) {
  if (argc < 2) {
    cout << "Moldorian ROM preparer" << endl;
    cout << "Usage: " << argv[0] << " [inrom] [outrom]" << endl;
    
    return 0;
  }
  
  string romName = string(argv[1]);
  string outRomName = string(argv[2]);
  
  TBufStream ifs;
  ifs.open(romName.c_str());
  
  // expand ROM
//  ifs.padToSize(outRomSize, 0xFF);
  
  ifs.save(outRomName.c_str());
  
  return 0;
}

