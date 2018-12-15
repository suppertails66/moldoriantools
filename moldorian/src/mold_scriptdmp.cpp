#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TThingyTable.h"
#include "exception/TGenericException.h"
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>

using namespace std;
using namespace BlackT;

TThingyTable table;

const static int op_br   = 0x90;
const static int op_wait = 0x91;
const static int op_hero = 0x92;
const static int op_op93 = 0x93;
const static int op_terminator = 0xFF;

void dumpString(TStream& ifs, std::ostream& ofs, int offset, int slot,
              string comment = "") {
  ifs.seek(offset);
  
  std::ostringstream oss;
  
  if (comment.size() > 0)
    oss << "// " << comment << endl;
  
  // comment out first line of original text
  oss << "// ";
  int last = -1;
  bool waitBrPending = false;
  int lastLineCharCount = 0;
  while (true) {
    
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "dumpString(TStream&, std::ostream&)",
                              string("At offset ")
                                + TStringConversion::intToString(
                                    ifs.tell(),
                                    TStringConversion::baseHex)
                                + ": unknown character '"
                                + TStringConversion::intToString(
                                    (unsigned char)ifs.peek(),
                                    TStringConversion::baseHex)
                                + "'");
    }
    
    string resultStr = table.getEntry(result.id);
    oss << resultStr;
    
/*    if ((result.id == op_wait) || (result.id == op_terminator)) {
      if (waitBrPending) {
        oss << endl;
        oss << table.getEntry(op_br);
//        oss << table.getEntry(op_br) << endl;
//        oss << endl;
        waitBrPending = false;
      }
    } */
    
    if (result.id < 0x90) ++lastLineCharCount;
    
    if (result.id == op_terminator) {
//      oss << endl;
      oss << endl << endl;
      oss << resultStr;
      break;
    }
    else if (result.id == op_br) {
      oss << endl;
//      oss << endl << endl;
//      oss << resultStr;
//      oss << endl << endl;
      
      // comment out original text
      oss << "// ";
      
      lastLineCharCount = 0;
//      if (last == op_wait) waitBrPending = true;
    }
    else if (result.id == op_wait) {
//      oss << endl;
      oss << endl << endl;
      oss << resultStr;
      
/*      if (((unsigned char)ifs.peek() == op_br)
          || ((lastLineCharCount == 16)
              && ((unsigned char)ifs.peek() != op_terminator))) {
        oss << table.getEntry(op_br);
      } */
      
      if ((unsigned char)ifs.peek() != op_terminator) {
        oss << table.getEntry(op_br);
      }
      
      // comment out original text
      oss << endl << endl;
      oss << "// ";
    }
    
    last = result.id;
  }
  
  ofs << "#STARTMSG("
      // offset
      << TStringConversion::intToString(
          offset, TStringConversion::baseHex)
      << ", "
      // size
      << TStringConversion::intToString(
          ifs.tell() - offset, TStringConversion::baseDec)
      << ", "
      // slot num
      << TStringConversion::intToString(
          slot, TStringConversion::baseDec)
      << ")" << endl << endl;
  
  ofs << oss.str();
  
//  oss << endl;
  ofs << endl << endl;
//  ofs << "//   end pos: "
//      << TStringConversion::intToString(
//          ifs.tell(), TStringConversion::baseHex)
//      << endl;
//  ofs << "//   size: " << ifs.tell() - offset << endl;
  ofs << endl;
  ofs << "#ENDMSG()";
  ofs << endl << endl;
}

void dumpStringSet(TStream& ifs, std::ostream& ofs, int startOffset, int slot,
               int numStrings,
               string comment = "") {
  if (comment.size() > 0) {
    ofs << "//=======================================" << endl;
    ofs << "// " << comment << endl;
    ofs << "//=======================================" << endl;
    ofs << endl;
  }
  
  ifs.seek(startOffset);
  for (int i = 0; i < numStrings; i++) {
    ofs << "// substring " << i << endl;
    dumpString(ifs, ofs, ifs.tell(), slot);
  }
}

//void dumpString(TStream& ifs, std::ostream& ofs, int offset) {
//  ifs.seek(offset);
//  dumpString(ifs, ofs);
//}

int main(int argc, char* argv[]) {
  if (argc < 4) {
    cout << "Moldorian script dumper" << endl;
    cout << "Usage: " << argv[0] << " [rom] [thingy] [outprefix]" << endl;
    
    return 0;
  }
  
  string romName = string(argv[1]);
  string tableName = string(argv[2]);
  string outPrefix = string(argv[3]);
  
  TBufStream ifs;
  ifs.open(romName.c_str());
  
  table.readSjis(tableName);
  
  std::ofstream ofs((outPrefix + "script.txt").c_str(),
                ios_base::binary);
  
//  ofs << "//===========================================" << endl;
//  ofs << "// yes/no prompt" << endl;
//  ofs << "//===========================================" << endl;
//  ofs << endl;
//  dumpString(ifs, ofs, 0x1233, 0, "yes prompt");
//  dumpString(ifs, ofs, 0x1236, 0, "no prompt");
  
  dumpStringSet(ifs, ofs, 0x1233, 0, 2, "yes/no prompt");
  dumpStringSet(ifs, ofs, 0x18CF, 0, 1, "item count??");
  dumpStringSet(ifs, ofs, 0x2CB9, 0, 15, "name entry screen characters");
  dumpStringSet(ifs, ofs, 0x3270, 0, 1, "name entry confirmation prompt");
  dumpStringSet(ifs, ofs, 0x3E0E, 0, 2, "loot acquired messages");
  dumpStringSet(ifs, ofs, 0x3EFD, 0, 16, "status menu?");
  dumpStringSet(ifs, ofs, 0x4552, 1, 2, "??? is this even two entries??");
  dumpStringSet(ifs, ofs, 0x49B8, 1, 1, "empty file name marker");
  dumpStringSet(ifs, ofs, 0x49BA, 1, 1, "optimized empty file level marker");
  dumpStringSet(ifs, ofs, 0x4AA2, 1, 4, "startup menu 1");
  dumpStringSet(ifs, ofs, 0x4ABC, 1, 11, "startup menu 2");
  dumpStringSet(ifs, ofs, 0x4C08 + 0, 0, 1, "?");
  dumpStringSet(ifs, ofs, 0x4EB3, 1, 5, "main menu");
  dumpStringSet(ifs, ofs, 0x4F9A, 1, 2, "'system' menu");
  dumpStringSet(ifs, ofs, 0x51FD, 1, 6, "speed menu");
  dumpStringSet(ifs, ofs, 0x5801, 1, 2, "magic menu?");
  dumpStringSet(ifs, ofs, 0x5963, 1, 2, "'use' menu?");
  dumpStringSet(ifs, ofs, 0x59DE, 1, 1, "'drop' menu 1?");
  dumpStringSet(ifs, ofs, 0x5ACA, 1, 4, "'drop' menu 2?");
  dumpStringSet(ifs, ofs, 0x5B58, 1, 1, "'drop' menu 3?");
  dumpStringSet(ifs, ofs, 0x5BD1, 1, 3, "item menu?");
  dumpStringSet(ifs, ofs, 0x5C92, 1, 1, "item menu?");
  dumpStringSet(ifs, ofs, 0x5E2B + 0, 0, 1, "?");
  dumpStringSet(ifs, ofs, 0x5EA7, 1, 5, "item menu?");
  dumpStringSet(ifs, ofs, 0x5F10, 1, 2, "item menu?");
  dumpStringSet(ifs, ofs, 0x5FD6, 1, 1, "item menu?");
  dumpStringSet(ifs, ofs, 0x6094 + 0, 0, 1, "?");
  dumpStringSet(ifs, ofs, 0x60ED + 0, 0, 1, "?");
  dumpStringSet(ifs, ofs, 0x6110, 1, 3, "item menu?");
  dumpStringSet(ifs, ofs, 0x6252, 1, 15, "equipment menu?");
  dumpStringSet(ifs, ofs, 0x646E, 1, 3, "equipment menu?");
  dumpStringSet(ifs, ofs, 0x6649, 1, 1, "equipment menu?");
  dumpStringSet(ifs, ofs, 0x670C, 1, 2, "equipment menu?");
  dumpStringSet(ifs, ofs, 0x67BB, 1, 1, "equipment menu?");
  dumpStringSet(ifs, ofs, 0x6BBE, 1, 8, "equipment menu?");
  dumpStringSet(ifs, ofs, 0x6D55, 1, 10, "equipment menu?");
  dumpStringSet(ifs, ofs, 0x6DC4, 1, 3, "shop menu?");
  dumpStringSet(ifs, ofs, 0x6E49, 1, 1, "shop menu?");
  dumpStringSet(ifs, ofs, 0x71AF, 1, 2, "shop menu?");
  // these aren't all one continuous set, right?
  dumpStringSet(ifs, ofs, 0x7544, 1, 9, "magic menu?");
  dumpStringSet(ifs, ofs, 0x75B2, 1, 3, "magic menu?");
  dumpStringSet(ifs, ofs, 0x75DE, 1, 2, "magic menu?");
  dumpStringSet(ifs, ofs, 0x75FE, 1, 2, "magic menu?");
  dumpStringSet(ifs, ofs, 0x761A, 1, 3, "magic menu?");
  dumpStringSet(ifs, ofs, 0x7666, 1, 1, "?");
  dumpStringSet(ifs, ofs, 0x77C8, 1, 2, "?");
  dumpStringSet(ifs, ofs, 0x7AC0, 1, 1, "healer menu");
  dumpStringSet(ifs, ofs, 0x8135 + 0, 1, 1, "?");
  dumpStringSet(ifs, ofs, 0x8334, 1, 9, "battle?");
  dumpStringSet(ifs, ofs, 0x86BA + 0, 1, 1, "?");
  dumpStringSet(ifs, ofs, 0x89DB, 1, 7, "battle?");
  dumpStringSet(ifs, ofs, 0x8DAA, 1, 2, "battle?");
  dumpStringSet(ifs, ofs, 0x9B57, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0x9E5E, 1, 2, "battle?");
  dumpStringSet(ifs, ofs, 0x9EBD, 1, 2, "battle?");
  dumpStringSet(ifs, ofs, 0xA309, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xA3D0, 1, 2, "battle?");
  dumpStringSet(ifs, ofs, 0xA41B, 1, 24, "battle?");
  dumpStringSet(ifs, ofs, 0xA844, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB082, 1, 3, "battle?");
  dumpStringSet(ifs, ofs, 0xB0D9, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB156, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB22C, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB2A2, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB30A, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB3B2, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB419, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB4B1, 1, 2, "battle?");
  dumpStringSet(ifs, ofs, 0xB4FE, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB543, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB583, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB5C5, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB5EA, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB714, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB729, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB740, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB765, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xB7E3, 1, 2, "battle?");
  dumpStringSet(ifs, ofs, 0xB803, 1, 1, "battle?");
  dumpStringSet(ifs, ofs, 0xBDC7, 1, 14, "battle?");
  dumpStringSet(ifs, ofs, 0xD99F, 1, 28, "intro");
  dumpStringSet(ifs, ofs, 0xDF10, 1, 1, "warp?");
  dumpStringSet(ifs, ofs, 0xDF87, 1, 13, "warp destinations?");
  dumpStringSet(ifs, ofs, 0xE2A7 + 0, 1, 1, "?");
  dumpStringSet(ifs, ofs, 0xE306, 1, 1, "?");
  dumpStringSet(ifs, ofs, 0xE418, 1, 2, "?");
  dumpStringSet(ifs, ofs, 0xE86F, 1, 40, "?");
  dumpStringSet(ifs, ofs, 0xEC39, 1, 111, "?");
  dumpStringSet(ifs, ofs, 0x10187, 1, 16, "shop dialogue?");
  dumpStringSet(ifs, ofs, 0x10429, 1, 1, "?");
  dumpStringSet(ifs, ofs, 0x10635, 1, 10, "maps");
  dumpStringSet(ifs, ofs, 0x10953, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x10BFE, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x10D30, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x10D6E, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x10E34, 1, 3, "maps");
  dumpStringSet(ifs, ofs, 0x10F17, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x10F74, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x11001, 1, 5, "maps");
  dumpStringSet(ifs, ofs, 0x1116C, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x111B9, 1, 16, "maps");
  dumpStringSet(ifs, ofs, 0x112AA, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x112EB, 1, 5, "maps");
  dumpStringSet(ifs, ofs, 0x11422, 1, 7, "maps");
  dumpStringSet(ifs, ofs, 0x1160B, 1, 7, "maps");
  dumpStringSet(ifs, ofs, 0x1186E, 1, 7, "maps");
  dumpStringSet(ifs, ofs, 0x11B21, 1, 10, "maps");
  dumpStringSet(ifs, ofs, 0x11CF7, 1, 3, "maps");
  dumpStringSet(ifs, ofs, 0x11DE9, 1, 4, "maps");
  dumpStringSet(ifs, ofs, 0x11EA2, 1, 3, "maps");
  dumpStringSet(ifs, ofs, 0x11F5E, 1, 7, "maps");
  dumpStringSet(ifs, ofs, 0x120C6, 1, 4, "maps");
  dumpStringSet(ifs, ofs, 0x1229E, 1, 3, "maps");
  dumpStringSet(ifs, ofs, 0x1230B, 1, 3, "maps");
  dumpStringSet(ifs, ofs, 0x12418, 1, 5, "maps");
  dumpStringSet(ifs, ofs, 0x125B6, 1, 6, "maps");
  dumpStringSet(ifs, ofs, 0x126FE, 1, 4, "maps");
  dumpStringSet(ifs, ofs, 0x128E9, 1, 6, "maps");
  dumpStringSet(ifs, ofs, 0x12A46, 1, 35, "shop?");
  dumpStringSet(ifs, ofs, 0x12CAD, 1, 3, "maps");
  dumpStringSet(ifs, ofs, 0x12D1B, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x12F02, 1, 7, "maps");
  dumpStringSet(ifs, ofs, 0x13108, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x1331E, 1, 4, "maps");
  dumpStringSet(ifs, ofs, 0x133F5, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x1344F, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x13717, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x13779, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x137F0, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x13841, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x1389D, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x138D3, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x13978, 1, 1, "maps");
  dumpStringSet(ifs, ofs, 0x13C03, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x13C48, 1, 2, "maps");
  dumpStringSet(ifs, ofs, 0x13DBE, 1, 8, "maps");
  dumpStringSet(ifs, ofs, 0x13F02, 1, 3, "maps");
  dumpStringSet(ifs, ofs, 0x13F7C, 1, 2, "maps");
//  dumpStringSet(ifs, ofs, 0x14060, 1, 16, "maps");
  // three (actually four) more banks of doing this manually was more than
  // i could take
  dumpStringSet(ifs, ofs, 0x1405E + 2, 1, 16, "autogen maps 69");
  dumpStringSet(ifs, ofs, 0x143F0, 1, 5, "autogen maps 70");
  dumpStringSet(ifs, ofs, 0x14508, 1, 2, "autogen maps 71");
  dumpStringSet(ifs, ofs, 0x1466D, 1, 4, "autogen maps 72");
//  dumpStringSet(ifs, ofs, 0x148AB, 1, 3, "autogen maps 73");
  dumpStringSet(ifs, ofs, 0x14920, 1, 2, "autogen maps 74");
  dumpStringSet(ifs, ofs, 0x14B49, 1, 4, "autogen maps 75");
  dumpStringSet(ifs, ofs, 0x14D21 + 1, 1, 1, "autogen maps 76");
  dumpStringSet(ifs, ofs, 0x14D5D, 1, 1, "autogen maps 77");
//  dumpStringSet(ifs, ofs, 0x14D77, 1, 1, "autogen maps 78");
  dumpStringSet(ifs, ofs, 0x14D7E + 2, 1, 2, "autogen maps 79");
  dumpStringSet(ifs, ofs, 0x14DD7 + 3, 1, 3, "autogen maps 80");
//  dumpStringSet(ifs, ofs, 0x14E54, 1, 1, "autogen maps 81");
  dumpStringSet(ifs, ofs, 0x14E5E + 2, 1, 3, "autogen maps 82");
//  dumpStringSet(ifs, ofs, 0x14EDC, 1, 1, "autogen maps 83");
  dumpStringSet(ifs, ofs, 0x14F1F, 1, 5, "autogen maps 84");
  dumpStringSet(ifs, ofs, 0x14FFA + 3, 1, 3, "autogen maps 85");
//  dumpStringSet(ifs, ofs, 0x1508C, 1, 1, "autogen maps 86");
  dumpStringSet(ifs, ofs, 0x1508F + 2, 1, 3, "autogen maps 87");
//  dumpStringSet(ifs, ofs, 0x150EF, 1, 1, "autogen maps 88");
  dumpStringSet(ifs, ofs, 0x151FE, 1, 15, "autogen maps 89");
//  dumpStringSet(ifs, ofs, 0x154BD, 1, 2, "autogen maps 90");
  dumpStringSet(ifs, ofs, 0x154CB + 1, 1, 1, "autogen maps 91");
  dumpStringSet(ifs, ofs, 0x15502 + 3, 1, 2, "autogen maps 92");
  dumpStringSet(ifs, ofs, 0x15556 + 3, 1, 2, "autogen maps 93");
//  dumpStringSet(ifs, ofs, 0x155B9, 1, 1, "autogen maps 94");
  dumpStringSet(ifs, ofs, 0x15664, 1, 8, "autogen maps 95");
  dumpStringSet(ifs, ofs, 0x158CF + 1, 1, 1, "autogen maps 96");
//  dumpStringSet(ifs, ofs, 0x158F4, 1, 1, "autogen maps 97");
  dumpStringSet(ifs, ofs, 0x15A65 + 1, 1, 1, "autogen maps 98");
  dumpStringSet(ifs, ofs, 0x15B04 + 3, 1, 2, "autogen maps 99");
//  dumpStringSet(ifs, ofs, 0x15B6A, 1, 1, "autogen maps 100");
  dumpStringSet(ifs, ofs, 0x15B71 + 2, 1, 2, "autogen maps 101");
  dumpStringSet(ifs, ofs, 0x15BE7 + 3, 1, 2, "autogen maps 102");
//  dumpStringSet(ifs, ofs, 0x15C7E, 1, 1, "autogen maps 103");
  dumpStringSet(ifs, ofs, 0x15C85 + 2, 1, 2, "autogen maps 104");
//  dumpStringSet(ifs, ofs, 0x15CCB, 1, 1, "autogen maps 105");
  dumpStringSet(ifs, ofs, 0x15FBB + 30, 1, 20, "autogen maps 106");
  dumpStringSet(ifs, ofs, 0x16714 + 1, 1, 1, "autogen maps 107");
  dumpStringSet(ifs, ofs, 0x16741 + 1, 1, 1, "autogen maps 108");
  dumpStringSet(ifs, ofs, 0x1675A + 3, 1, 2, "autogen maps 109");
  dumpStringSet(ifs, ofs, 0x1679E + 1, 1, 1, "autogen maps 110");
  dumpStringSet(ifs, ofs, 0x168C5, 1, 8, "autogen maps 111");
  dumpStringSet(ifs, ofs, 0x16B7E, 1, 5, "autogen maps 112");
  dumpStringSet(ifs, ofs, 0x16E2F + 1, 1, 1, "autogen maps 113");
  dumpStringSet(ifs, ofs, 0x16E9E, 1, 2, "autogen maps 114");
  dumpStringSet(ifs, ofs, 0x1701E + 1, 1, 1, "autogen maps 115");
//  dumpStringSet(ifs, ofs, 0x1704B, 1, 1, "autogen maps 116");
  dumpStringSet(ifs, ofs, 0x17058 + 2, 1, 3, "autogen maps 117");
  dumpStringSet(ifs, ofs, 0x17114 + 3, 1, 3, "autogen maps 118");
//  dumpStringSet(ifs, ofs, 0x171A3, 1, 1, "autogen maps 119");
  dumpStringSet(ifs, ofs, 0x171A6 + 2, 1, 2, "autogen maps 120");
  dumpStringSet(ifs, ofs, 0x17224 + 1, 1, 1, "autogen maps 121");
  dumpStringSet(ifs, ofs, 0x17254 + 3, 1, 2, "autogen maps 122");
//  dumpStringSet(ifs, ofs, 0x172BF, 1, 1, "autogen maps 123");
  dumpStringSet(ifs, ofs, 0x173BA, 1, 14, "autogen maps 124");
  dumpStringSet(ifs, ofs, 0x17823 + 1, 1, 1, "autogen maps 125");
  dumpStringSet(ifs, ofs, 0x178E7 + 1, 1, 1, "autogen maps 126");
  dumpStringSet(ifs, ofs, 0x17978 + 0, 1, 4, "autogen maps 127");
  dumpStringSet(ifs, ofs, 0x17CB4 + 0, 1, 1, "autogen maps 128");
  dumpStringSet(ifs, ofs, 0x17E9C + 0, 1, 2, "autogen maps 129");
//  dumpStringSet(ifs, ofs, 0x17F1F + 0, 1, 225, "autogen maps 130");
  dumpStringSet(ifs, ofs, 0x1805E + 2, 1, 16, "autogen maps 131");
  dumpStringSet(ifs, ofs, 0x182A6 + 0, 1, 1, "autogen maps 132");
  dumpStringSet(ifs, ofs, 0x18327 + 0, 1, 4, "autogen maps 133");
//  dumpStringSet(ifs, ofs, 0x183E2 + 0, 1, 1, "autogen maps 134");
  dumpStringSet(ifs, ofs, 0x1840E + 0, 1, 3, "autogen maps 135");
  dumpStringSet(ifs, ofs, 0x1847F + 0, 1, 1, "autogen maps 136");
  dumpStringSet(ifs, ofs, 0x18498 + 1, 1, 1, "autogen maps 137");
  dumpStringSet(ifs, ofs, 0x184B7 + 1, 1, 1, "autogen maps 138");
  dumpStringSet(ifs, ofs, 0x184E1 + 1, 1, 1, "autogen maps 139");
  dumpStringSet(ifs, ofs, 0x18518 + 3, 1, 2, "autogen maps 140");
  dumpStringSet(ifs, ofs, 0x18576 + 1, 1, 1, "autogen maps 141");
  dumpStringSet(ifs, ofs, 0x1859D + 1, 1, 1, "autogen maps 142");
  dumpStringSet(ifs, ofs, 0x185CE + 1, 1, 1, "autogen maps 143");
//  dumpStringSet(ifs, ofs, 0x18634 + 0, 1, 1, "autogen maps 144");
  dumpStringSet(ifs, ofs, 0x18765 + 1, 1, 1, "autogen maps 145");
  dumpStringSet(ifs, ofs, 0x18896 + 0, 1, 6, "autogen maps 146");
  dumpStringSet(ifs, ofs, 0x18A13 + 0, 1, 1, "autogen maps 147");
  dumpStringSet(ifs, ofs, 0x18A86 + 0, 1, 2, "autogen maps 148");
  dumpStringSet(ifs, ofs, 0x18ACE + 1, 1, 1, "autogen maps 149");
  dumpStringSet(ifs, ofs, 0x18ADF + 1, 1, 1, "autogen maps 150");
  dumpStringSet(ifs, ofs, 0x18B18 + 3, 1, 3, "autogen maps 151");
  dumpStringSet(ifs, ofs, 0x18B68 + 1, 1, 1, "autogen maps 152");
  dumpStringSet(ifs, ofs, 0x18B98 + 1, 1, 1, "autogen maps 153");
  dumpStringSet(ifs, ofs, 0x18BC2 + 0, 1, 1, "autogen maps 154");
  dumpStringSet(ifs, ofs, 0x18BDD + 0, 1, 3, "autogen maps 155");
  dumpStringSet(ifs, ofs, 0x18C4B + 1, 1, 1, "autogen maps 156");
  dumpStringSet(ifs, ofs, 0x18C88 + 0, 1, 1, "autogen maps 157");
//  dumpStringSet(ifs, ofs, 0x18CAD + 0, 1, 1, "autogen maps 158");
  dumpStringSet(ifs, ofs, 0x18F7A + 0, 1, 5, "autogen maps 159");
//  dumpStringSet(ifs, ofs, 0x191F1 + 0, 1, 2, "autogen maps 160");
//  dumpStringSet(ifs, ofs, 0x19267 + 0, 1, 1, "autogen maps 161");
  dumpStringSet(ifs, ofs, 0x192AA + 0, 1, 9, "autogen maps 162");
//  dumpStringSet(ifs, ofs, 0x19431 + 0, 1, 1, "autogen maps 163");
  dumpStringSet(ifs, ofs, 0x194B8 + 0, 1, 6, "autogen maps 164");
  dumpStringSet(ifs, ofs, 0x195FF + 1, 1, 1, "autogen maps 165");
  dumpStringSet(ifs, ofs, 0x19615 + 1, 1, 1, "autogen maps 166");
  dumpStringSet(ifs, ofs, 0x19640 + 1, 1, 1, "autogen maps 167");
  dumpStringSet(ifs, ofs, 0x1966F + 1, 1, 1, "autogen maps 168");
//  dumpStringSet(ifs, ofs, 0x198C3 + 0, 1, 1, "autogen maps 169");
  dumpStringSet(ifs, ofs, 0x199FB + 0, 1, 38, "autogen maps 170");
  dumpStringSet(ifs, ofs, 0x19EC1 + 2, 1, 1, "autogen maps 171");
  dumpStringSet(ifs, ofs, 0x19FED + 0, 1, 2, "autogen maps 172");
  dumpStringSet(ifs, ofs, 0x1A16A + 1, 1, 1, "autogen maps 173");
//  dumpStringSet(ifs, ofs, 0x1A1A4 + 0, 1, 1, "autogen maps 174");
  dumpStringSet(ifs, ofs, 0x1A1A7 + 2, 1, 2, "autogen maps 175");
  dumpStringSet(ifs, ofs, 0x1A213 + 0, 1, 2, "autogen maps 176");
  dumpStringSet(ifs, ofs, 0x1A275 + 1, 1, 1, "autogen maps 177");
//  dumpStringSet(ifs, ofs, 0x1A2A9 + 0, 1, 1, "autogen maps 178");
  dumpStringSet(ifs, ofs, 0x1A2AC + 2, 1, 2, "autogen maps 179");
  dumpStringSet(ifs, ofs, 0x1A30D + 3, 1, 2, "autogen maps 180");
  dumpStringSet(ifs, ofs, 0x1A390 + 0, 1, 2, "autogen maps 181");
  dumpStringSet(ifs, ofs, 0x1A3BA + 1, 1, 1, "autogen maps 182");
  dumpStringSet(ifs, ofs, 0x1A3E9 + 2, 1, 2, "autogen maps 183");
  dumpStringSet(ifs, ofs, 0x1A676 + 0, 1, 2, "autogen maps 184");
//  dumpStringSet(ifs, ofs, 0x1A8A5 + 0, 1, 1, "autogen maps 185");
  dumpStringSet(ifs, ofs, 0x1AADC + 1, 1, 22, "autogen maps 186");
  dumpStringSet(ifs, ofs, 0x1AF03 + 1, 1, 1, "autogen maps 187");
//  dumpStringSet(ifs, ofs, 0x1AF39 + 0, 1, 1, "autogen maps 188");
  dumpStringSet(ifs, ofs, 0x1AF70 + 0, 1, 3, "autogen maps 189");
  dumpStringSet(ifs, ofs, 0x1B047 + 3, 1, 2, "autogen maps 190");
  dumpStringSet(ifs, ofs, 0x1B0CE + 3, 1, 2, "autogen maps 191");
//  dumpStringSet(ifs, ofs, 0x1B13C + 0, 1, 1, "autogen maps 192");
  dumpStringSet(ifs, ofs, 0x1B16B + 0, 1, 2, "autogen maps 193");
//  dumpStringSet(ifs, ofs, 0x1B1D6 + 0, 1, 1, "autogen maps 194");
  dumpStringSet(ifs, ofs, 0x1B204 + 0, 1, 3, "autogen maps 195");
//  dumpStringSet(ifs, ofs, 0x1B25F + 0, 1, 1, "autogen maps 196");
  dumpStringSet(ifs, ofs, 0x1B285 + 0, 1, 3, "autogen maps 197");
  dumpStringSet(ifs, ofs, 0x1B478 + 2, 1, 18, "autogen maps 198");
  dumpStringSet(ifs, ofs, 0x1B845 + 1, 1, 3, "autogen maps 199");
  dumpStringSet(ifs, ofs, 0x1B9A7 + 1, 1, 1, "autogen maps 200");
  dumpStringSet(ifs, ofs, 0x1B9F2 + 1, 1, 1, "autogen maps 201");
//  dumpStringSet(ifs, ofs, 0x1BA11 + 0, 1, 1519, "autogen maps 202");
  dumpStringSet(ifs, ofs, 0x1C05E + 2, 1, 16, "autogen maps 203");
//  dumpStringSet(ifs, ofs, 0x1C321 + 0, 1, 2, "autogen maps 204");
//  dumpStringSet(ifs, ofs, 0x1C3B5 + 0, 1, 1, "autogen maps 205");
  dumpStringSet(ifs, ofs, 0x1C55A + 2, 1, 16, "autogen maps 206");
  dumpStringSet(ifs, ofs, 0x1CB09 + 0, 1, 1, "autogen maps 207");
  dumpStringSet(ifs, ofs, 0x1CC70 + 0, 1, 19, "autogen maps 208");
//  dumpStringSet(ifs, ofs, 0x1D0B0 + 0, 1, 1, "autogen maps 209");
  dumpStringSet(ifs, ofs, 0x1D17D + 0, 1, 5, "autogen maps 210");
//  dumpStringSet(ifs, ofs, 0x1D320 + 0, 1, 1, "autogen maps 211");
  dumpStringSet(ifs, ofs, 0x1D352 + 0, 1, 4, "autogen maps 212");
  dumpStringSet(ifs, ofs, 0x1D3EA + 0, 1, 1, "autogen maps 213");
//  dumpStringSet(ifs, ofs, 0x1D461 + 0, 1, 1, "autogen maps 214");
//  dumpStringSet(ifs, ofs, 0x1D4C3 + 0, 1, 1, "autogen maps 215");
  // is this correct?
  dumpStringSet(ifs, ofs, 0x1D503 + 1, 1, 4, "autogen maps 216");
//  dumpStringSet(ifs, ofs, 0x1D5F0 + 0, 1, 1, "autogen maps 217");
  // is this correct?
  dumpStringSet(ifs, ofs, 0x1D5FE + 1, 1, 1, "autogen maps 218");
  dumpStringSet(ifs, ofs, 0x1D911 + 0, 1, 18, "autogen maps 219");
  dumpStringSet(ifs, ofs, 0x1E037 + 0, 1, 1, "autogen maps 220");
  dumpStringSet(ifs, ofs, 0x1E0AD + 1, 1, 1, "autogen maps 221");
  dumpStringSet(ifs, ofs, 0x1E0F4 + 0, 1, 1, "autogen maps 222");
  dumpStringSet(ifs, ofs, 0x1E11D + 0, 1, 1, "autogen maps 223");
  dumpStringSet(ifs, ofs, 0x1E146 + 0, 1, 1, "autogen maps 224");
  dumpStringSet(ifs, ofs, 0x1E16C + 0, 1, 1, "autogen maps 225");
  dumpStringSet(ifs, ofs, 0x1E263 + 0, 1, 6, "autogen maps 226");
  dumpStringSet(ifs, ofs, 0x1E2FD + 0, 1, 1, "autogen maps 227");
  dumpStringSet(ifs, ofs, 0x1E3ED + 0, 1, 9, "autogen maps 228");
  dumpStringSet(ifs, ofs, 0x1E5D1 + 0, 1, 1, "autogen maps 229");
  dumpStringSet(ifs, ofs, 0x1E616 + 0, 1, 1, "autogen maps 230");
  dumpStringSet(ifs, ofs, 0x1E791 + 0, 1, 1, "autogen maps 231");
  dumpStringSet(ifs, ofs, 0x1EF1B + 0, 1, 2, "autogen maps 232");
//  dumpStringSet(ifs, ofs, 0x1EF90 + 0, 1, 1, "autogen maps 233");
  dumpStringSet(ifs, ofs, 0x1EF93 + 2, 1, 1, "autogen maps 234");
//  dumpStringSet(ifs, ofs, 0x1EFF4 + 0, 1, 1, "autogen maps 235");
  dumpStringSet(ifs, ofs, 0x1EFFE + 2, 1, 3, "autogen maps 236");
  dumpStringSet(ifs, ofs, 0x1F0D6 + 3, 1, 2, "autogen maps 237");
//  dumpStringSet(ifs, ofs, 0x1F15D + 0, 1, 1, "autogen maps 238");
  dumpStringSet(ifs, ofs, 0x1F164 + 2, 1, 2, "autogen maps 239");
//  dumpStringSet(ifs, ofs, 0x1F200 + 0, 1, 1, "autogen maps 240");
  dumpStringSet(ifs, ofs, 0x1F23F + 0, 1, 4, "autogen maps 241");
//  dumpStringSet(ifs, ofs, 0x1F383 + 0, 1, 1, "autogen maps 242");
  dumpStringSet(ifs, ofs, 0x1F3BF + 0, 1, 5, "autogen maps 243");
//  dumpStringSet(ifs, ofs, 0x1F526 + 0, 1, 1, "autogen maps 244");
  dumpStringSet(ifs, ofs, 0x1F6A4 + 2, 1, 5, "autogen maps 245");
  dumpStringSet(ifs, ofs, 0x1F965 + 0, 1, 10, "autogen maps 246");
//  dumpStringSet(ifs, ofs, 0x1FBA7 + 0, 1, 1, "autogen maps 247");
  dumpStringSet(ifs, ofs, 0x1FBF7 + 0, 1, 5, "autogen maps 248");
//  dumpStringSet(ifs, ofs, 0x1FD61 + 0, 1, 1, "autogen maps 249");
  dumpStringSet(ifs, ofs, 0x1FDE5 + 0, 1, 6, "autogen maps 250");
  dumpStringSet(ifs, ofs, 0x1FEBA + 0, 1, 1, "autogen maps 251");
//  dumpStringSet(ifs, ofs, 0x1FEFC + 0, 1, 259, "autogen maps 252");
  dumpStringSet(ifs, ofs, 0x2005E + 2, 1, 16, "autogen maps 253");
  dumpStringSet(ifs, ofs, 0x20226 + 1, 1, 1, "autogen maps 254");
  dumpStringSet(ifs, ofs, 0x20253 + 1, 1, 1, "autogen maps 255");
  dumpStringSet(ifs, ofs, 0x202BC + 1, 1, 1, "autogen maps 256");
  dumpStringSet(ifs, ofs, 0x202E7 + 1, 1, 1, "autogen maps 257");
  dumpStringSet(ifs, ofs, 0x2035C + 1, 1, 1, "autogen maps 258");
  dumpStringSet(ifs, ofs, 0x2038D + 1, 1, 1, "autogen maps 259");
  dumpStringSet(ifs, ofs, 0x203B1 + 1, 1, 1, "autogen maps 260");
  dumpStringSet(ifs, ofs, 0x203EA + 1, 1, 1, "autogen maps 261");
  dumpStringSet(ifs, ofs, 0x2046D + 0, 1, 2, "autogen maps 262");
  dumpStringSet(ifs, ofs, 0x204F5 + 1, 1, 1, "autogen maps 263");
  dumpStringSet(ifs, ofs, 0x20529 + 1, 1, 1, "autogen maps 264");
  dumpStringSet(ifs, ofs, 0x2054E + 2, 1, 1, "autogen maps 265");
  dumpStringSet(ifs, ofs, 0x20631 + 0, 1, 3, "autogen maps 266");
  dumpStringSet(ifs, ofs, 0x20896 + 1, 1, 1, "autogen maps 267");
  dumpStringSet(ifs, ofs, 0x20B62 + 0, 1, 20, "autogen maps 268");
//  dumpStringSet(ifs, ofs, 0x2103A + 0, 1, 1, "autogen maps 269");
  dumpStringSet(ifs, ofs, 0x212D5 + 0, 1, 9, "autogen maps 270");
  dumpStringSet(ifs, ofs, 0x215F8 + 0, 1, 2, "autogen maps 271");
  dumpStringSet(ifs, ofs, 0x216D3 + 5, 1, 1, "autogen maps 272");
  dumpStringSet(ifs, ofs, 0x2173D + 2, 1, 1, "autogen maps 273");
  dumpStringSet(ifs, ofs, 0x2177A + 2, 1, 1, "autogen maps 274");
  dumpStringSet(ifs, ofs, 0x217BA + 2, 1, 1, "autogen maps 275");
  dumpStringSet(ifs, ofs, 0x217F6 + 2, 1, 1, "autogen maps 276");
  dumpStringSet(ifs, ofs, 0x218F2 + 1, 1, 10, "autogen maps 277");
  dumpStringSet(ifs, ofs, 0x21B0B + 0, 1, 6, "autogen maps 278");
  dumpStringSet(ifs, ofs, 0x21BC8 + 0, 1, 2, "autogen maps 279");
  dumpStringSet(ifs, ofs, 0x21C02 + 6, 1, 2, "autogen maps 280");
  dumpStringSet(ifs, ofs, 0x21CAE + 2, 1, 5, "autogen maps 281");
  dumpStringSet(ifs, ofs, 0x21E89 + 0, 1, 1, "autogen maps 282");
  dumpStringSet(ifs, ofs, 0x22091 + 0, 1, 3, "autogen maps 283");
  dumpStringSet(ifs, ofs, 0x22327 + 1, 1, 1, "autogen maps 284");
  dumpStringSet(ifs, ofs, 0x2237C + 0, 1, 3, "autogen maps 285");
//  dumpStringSet(ifs, ofs, 0x2266F + 0, 1, 1, "autogen maps 286");
//  dumpStringSet(ifs, ofs, 0x226E3 + 0, 1, 5, "autogen maps 287");
//  dumpStringSet(ifs, ofs, 0x227D5 + 0, 1, 1, "autogen maps 288");
//  dumpStringSet(ifs, ofs, 0x22919 + 0, 1, 4, "autogen maps 289");
//  dumpStringSet(ifs, ofs, 0x22A0B + 0, 1, 5, "autogen maps 290");
//  dumpStringSet(ifs, ofs, 0x22B04 + 0, 1, 5, "autogen maps 291");
//  dumpStringSet(ifs, ofs, 0x22C7C + 0, 1, 1, "autogen maps 292");
//  dumpStringSet(ifs, ofs, 0x22DB4 + 0, 1, 2, "autogen maps 293");
//  dumpStringSet(ifs, ofs, 0x232CA + 0, 1, 13, "autogen maps 294");
  dumpStringSet(ifs, ofs, 0x481F7, 1, 7, "party member names?");
  dumpStringSet(ifs, ofs, 0x48C02, 1, 121, "items");
  dumpStringSet(ifs, ofs, 0x491FB, 1, 48, "spells");
  dumpStringSet(ifs, ofs, 0x4A195, 1, 105, "monsters");

//  dumpStringSet(ifs, ofs, 0x4B42, 1, 2, "?");
  
  return 0;
} 
