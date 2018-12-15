#include "moldorian/MoldorianScriptReader.h"
#include "util/TBufStream.h"
#include "util/TStringConversion.h"
#include "util/TParse.h"
#include "exception/TGenericException.h"
#include <cctype>
#include <algorithm>
#include <string>
#include <iostream>

using namespace BlackT;

namespace Sms {


const static int scriptBufferCapacity = 0x10000;

MoldorianScriptReader::MoldorianScriptReader(
                  BlackT::TStream& src__,
                  ResultCollection& dst__,
                  const BlackT::TThingyTable& thingy__)
  : src(src__),
    dst(dst__),
    thingy(thingy__),
    lineNum(0),
    breakTriggered(false),
    currentScriptBuffer(scriptBufferCapacity) {
  loadThingy(thingy__);
//  spaceOfs.open((outprefix + "msg_space.txt").c_str());
//  indexOfs.open((outprefix + "msg_index.txt").c_str());
  resetScriptBuffer();
}

bool MoldorianScriptReader::operator()() {
  while (!src.eof()) {
    std::string line;
    src.getLine(line);
    ++lineNum;
    
//    std::cerr << lineNum << std::endl;
    if (line.size() <= 0) continue;
    
    // discard lines containing only ASCII spaces and tabs
//    bool onlySpace = true;
//    for (int i = 0; i < line.size(); i++) {
//      if ((line[i] != ' ')
//          && (line[i] != '\t')) {
//        onlySpace = false;
//        break;
//      }
//    }
//    if (onlySpace) continue;
    
    TBufStream ifs(line.size());
    ifs.write(line.c_str(), line.size());
    ifs.seek(0);
    
    // check for special stuff
    if (ifs.peek() == '#') {
      // directives
      ifs.get();
      processDirective(ifs);
      
      if (breakTriggered) {
        breakTriggered = false;
        return false;
      }
      
      continue;
    }
    
    while (!ifs.eof()) {
      // check for comments
      if ((ifs.remaining() >= 2)
          && (ifs.peek() == '/')) {
        ifs.get();
        if (ifs.peek() == '/') break;
        else ifs.unget();
      }
      
      outputNextSymbol(ifs);
    }
  }
  
  if (currentScriptBuffer.size() > 0) {
    flushActiveScript();
  }
  
  return true;
}
  
void MoldorianScriptReader::loadThingy(const BlackT::TThingyTable& thingy__) {
  thingy = thingy__;
}
  
void MoldorianScriptReader::outputNextSymbol(TStream& ifs) {
  // literal value
  if ((ifs.remaining() >= 5)
      && (ifs.peek() == '<')) {
    int pos = ifs.tell();
    
    ifs.get();
    if (ifs.peek() == '$') {
      ifs.get();
      std::string valuestr = "0x";
      valuestr += ifs.get();
      valuestr += ifs.get();
      
      if (ifs.peek() == '>') {
        ifs.get();
        int value = TStringConversion::stringToInt(valuestr);
        
//        dst.writeu8(value);
        currentScriptBuffer.writeu8(value);

        return;
      }
    }
    
    // not a literal value
    ifs.seek(pos);
  }
  
  TThingyTable::MatchResult result;
  result = thingy.matchTableEntry(ifs);
  
  if (result.id != -1) {
//    std::cerr << std::dec << lineNum << " " << std::hex << result.id << " " << result.size << std::endl;
  
    int symbolSize;
    if (result.id <= 0xFF) symbolSize = 1;
    else if (result.id <= 0xFFFF) symbolSize = 2;
    else if (result.id <= 0xFFFFFF) symbolSize = 3;
    else symbolSize = 4;
    
    currentScriptBuffer.writeInt(result.id, symbolSize,
      EndiannessTypes::big, SignednessTypes::nosign);
    
    return;
  }
  
  std::string remainder;
  ifs.getLine(remainder);
  
  // if we reached end of file, this is not an error: we're done
  if (ifs.eof()) return;
  
  throw TGenericException(T_SRCANDLINE,
                          "MoldorianScriptReader::outputNextSymbol()",
                          "Line "
                            + TStringConversion::intToString(lineNum)
                            + ":\n  Couldn't match symbol at: '"
                            + remainder
                            + "'");
}
  
void MoldorianScriptReader::flushActiveScript() {
  // write terminator
//  currentScriptBuffer.put(0x00);

  int outputSize = currentScriptBuffer.size();
  
  ResultString result;
  currentScriptBuffer.seek(0);
  while (!currentScriptBuffer.eof()) {
    result.str += currentScriptBuffer.get();
  }
  
  result.srcOffset = currentScriptSrcOffset;
  result.srcSize = currentScriptSrcSize;
  result.srcSlot = currentScriptSrcSlot;
  
  dst.push_back(result);
  
  // clear script buffer
  resetScriptBuffer();
}

void MoldorianScriptReader::resetScriptBuffer() {
  currentScriptBuffer = TBufStream(scriptBufferCapacity);
  currentScriptSrcOffset = -1;
  currentScriptSrcSize = -1;
  currentScriptSrcSlot = -1;
}
  
/*bool MoldorianScriptReader::checkSymbol(BlackT::TStream& ifs, std::string& symbol) {
  if (symbol.size() > ifs.remaining()) return false;
  
  int startpos = ifs.tell();
  for (int i = 0; i < symbol.size(); i++) {
    if (symbol[i] != ifs.get()) {
      ifs.seek(startpos);
      return false;
    }
  }
  
  return true;
} */

void MoldorianScriptReader::processDirective(BlackT::TStream& ifs) {
  TParse::skipSpace(ifs);
  
  std::string name = TParse::matchName(ifs);
  TParse::matchChar(ifs, '(');
  
  for (int i = 0; i < name.size(); i++) {
    name[i] = toupper(name[i]);
  }
  
  if (name.compare("LOADTABLE") == 0) {
    processLoadTable(ifs);
  }
  else if (name.compare("STARTMSG") == 0) {
    processStartMsg(ifs);
  }
  else if (name.compare("ENDMSG") == 0) {
    processEndMsg(ifs);
  }
  else if (name.compare("INCBIN") == 0) {
    processIncBin(ifs);
  }
  else if (name.compare("BREAK") == 0) {
    processBreak(ifs);
  }
  else {
    throw TGenericException(T_SRCANDLINE,
                            "MoldorianScriptReader::processDirective()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unknown directive: "
                              + name);
  }
  
  TParse::matchChar(ifs, ')');
}

void MoldorianScriptReader::processLoadTable(BlackT::TStream& ifs) {
  std::string tableName = TParse::matchString(ifs);
  TThingyTable table(tableName);
  loadThingy(table);
}

void MoldorianScriptReader::processStartMsg(BlackT::TStream& ifs) {
  currentScriptSrcOffset = TParse::matchInt(ifs);
  TParse::matchChar(ifs, ',');
  currentScriptSrcSize = TParse::matchInt(ifs);
  TParse::matchChar(ifs, ',');
  currentScriptSrcSlot = TParse::matchInt(ifs);
}

void MoldorianScriptReader::processEndMsg(BlackT::TStream& ifs) {
  flushActiveScript();
}

void MoldorianScriptReader::processIncBin(BlackT::TStream& ifs) {
  std::string filename = TParse::matchString(ifs);
  TBufStream src(1);
  src.open(filename.c_str());
  currentScriptBuffer.writeFrom(src, src.size());
}

void MoldorianScriptReader::processBreak(BlackT::TStream& ifs) {
  breakTriggered = true;
}


}
