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

TThingyTable table;

const static int searchStart = 0x00000;
const static int searchEnd   = 0x24000;

const static int op_br   = 0x90;
const static int op_wait = 0x91;
const static int op_hero = 0x92;
const static int op_op93 = 0x93;
const static int op_terminator = 0xFF;

int checkString(TStream& ifs, std::ostream& ofs) {
  int start = ifs.tell();
  while (true) {
    
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
/*      throw TGenericException(T_SRCANDLINE,
                              "dumpString(TStream&, std::ostream&)",
                              string("At offset ")
                                + TStringConversion::intToString(
                                    ifs.tell(),
                                    TStringConversion::baseHex)
                                + ": unknown character '"
                                + TStringConversion::intToString(
                                    (unsigned char)ifs.peek(),
                                    TStringConversion::baseHex)
                                + "'"); */
      ifs.seekoff(1);
      return -(ifs.tell() - start);
    }
    
//    string resultStr = table.getEntry(result.id);
//    ofs << resultStr;
    
    if (result.id == op_terminator) {
      return (ifs.tell() - start);
    }
  }
}

int dumpedTableCount = 0;

int dumpStringTable(TStream& ifs, std::ostream& ofs) {
  int pos = ifs.tell();
  int count = 0;
  
  int endpos = ifs.size();
  while (true) {
    int size = checkString(ifs, ofs);
    
    // no valid string at current pos
    if (ifs.eof() || (size < 0)) {
      // seek past invalid character, then terminate dumping
//      ifs.seekoff(-size);
      if (size < 0)
        endpos = (ifs.tell() + size);
      break;
    }
    else ++count;
  }
  
  // if at least one string was found, add rip entry
  // (discount results which consist of only a single terminator)
  if (((count == 1) && ((endpos - pos) > 1))
      || (count > 1)) {
//    std::cerr << std::hex << pos << " " << (ifs.tell() - pos) << std::endl;
    ofs << "  dumpStringSet(ifs, ofs, "
        << TStringConversion::intToString(pos, TStringConversion::baseHex)
        << " + 0, 1, "
        << count
        << ", \"autogen maps "
        << dumpedTableCount++
        << "\");"
        << endl;
//    dumpStringSet(ifs, ofs, 0x14060, 1, 16, "maps");
  }
  
//  if (((count == 1) && ((endpos - pos) <= 1))) {
//    std::cerr << std::hex << pos << " " << (endpos - pos) << std::endl;
//  }
  
  return count;
}

//void dumpString(TStream& ifs, std::ostream& ofs, int offset) {
//  ifs.seek(offset);
//  dumpString(ifs, ofs);
//}

int main(int argc, char* argv[]) {
  if (argc < 4) {
    cout << "Moldorian string searcher" << endl;
    cout << "Usage: " << argv[0] << " [rom] [thingy] [outprefix]" << endl;
    
    return 0;
  }
  
  string romName = string(argv[1]);
  string tableName = string(argv[2]);
  string outPrefix = string(argv[3]);
  
  TBufStream ifs;
  ifs.open(romName.c_str());
  
  table.readSjis(tableName);
  
  std::ofstream ofs((outPrefix + "string_rip_list.txt").c_str(),
                ios_base::binary);
  
  ifs.seek(searchStart);
  while (ifs.tell() < searchEnd) {
    dumpStringTable(ifs, ofs);
  }
  
  return 0;
}

