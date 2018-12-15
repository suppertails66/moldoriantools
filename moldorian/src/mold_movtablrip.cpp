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

const static int numIndices = 0x3F;

string as2bHex(int num) {
  string str = TStringConversion::intToString(num,
                TStringConversion::baseHex).substr(2, string::npos);
  while (str.size() < 2) str = "0" + str;
  return "$" + str;
}

void ripMoveTable(TBufStream& ifs, int pos) {
  
  cout << ";==================================" << endl;
  cout << "; movement table "
       << TStringConversion::intToString(pos, TStringConversion::baseHex)
       << endl;
  cout << ";==================================" << endl;
  cout << endl;
  
  ifs.seek(pos);
  for (int i = 0; i < numIndices; i++) {
    cout << "; index " << as2bHex(i) << endl;
    int up = (unsigned char)ifs.readu8();
    int down = (unsigned char)ifs.readu8();
    int left = (unsigned char)ifs.readu8();
    int right = (unsigned char)ifs.readu8();
    
    cout << ".db "
         << as2bHex(up)
         << ","
         << as2bHex(down)
         << ","
         << as2bHex(left)
         << ","
         << as2bHex(right)
         << endl;
  }
  
  cout << endl;
}

int main(int argc, char* argv[]) {
  if (argc < 2) {
    cout << "Moldorian movement table ripper" << endl;
    cout << "Usage: " << argv[0] << " [rom]" << endl;
    
    return 0;
  }
  
  string romName = string(argv[1]);
  
  TBufStream ifs;
  ifs.open(romName.c_str());
  
  ripMoveTable(ifs, 0x2E3E);
  ripMoveTable(ifs, 0x2F3A);
  
  cout << ";==================================" << endl;
  cout << "; tile pos table "
       << TStringConversion::intToString(0x2DC0, TStringConversion::baseHex)
       << endl;
  cout << ";==================================" << endl;
  cout << endl;
  
  ifs.seek(0x2DC0);
  for (int i = 0; i < numIndices; i++) {
    cout << "; index " << as2bHex(i) << endl;
    int x = (unsigned char)ifs.readu8();
    int y = (unsigned char)ifs.readu8();
    
    cout << ".db "
         << as2bHex(x)
         << ","
         << as2bHex(y)
         << endl;
  }
  
  return 0;
}

