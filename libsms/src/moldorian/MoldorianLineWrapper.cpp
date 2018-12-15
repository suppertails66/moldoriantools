#include "moldorian/MoldorianLineWrapper.h"
#include "util/TParse.h"
#include "util/TStringConversion.h"
#include "exception/TGenericException.h"
#include <iostream>

using namespace BlackT;

namespace Sms {

const static int maxHeroNameWidth = 35;

const static int controlOpsStart = 0x90;
const static int controlOpsEnd   = 0xA0;

const static int code_space   = 0x20;
const static int code_br      = 0x90;
const static int code_wait    = 0x91;
const static int code_hero    = 0x92;
const static int code_thing   = 0x93;
const static int code_end     = 0xFF;

// added for translation
const static int code_tilebr  = 0x94;

MoldorianLineWrapper::MoldorianLineWrapper(BlackT::TStream& src__,
                ResultCollection& dst__,
                const BlackT::TThingyTable& thingy__,
                CharSizeTable sizeTable__,
                int xSize__,
                int ySize__)
  : TLineWrapper(src__, dst__, thingy__, xSize__, ySize__),
    sizeTable(sizeTable__),
    xBeforeWait(-1),
    clearMode(clearMode_default) {
  
}

int MoldorianLineWrapper::widthOfKey(int key) {
  if ((key == code_br)) return 0;
  else if ((key == code_wait)) return 0;
  else if ((key == code_hero)) return maxHeroNameWidth;
  else if ((key == code_thing)) return 0;
  else if ((key == code_end)) return 0;
//  else if ((key == code_tilebr)) return 8;  // assume worst case
  else if ((key >= controlOpsStart) && (key < controlOpsEnd)) return 0;
  
  return sizeTable[key];
}

bool MoldorianLineWrapper::isWordDivider(int key) {
  if (
      (key == code_br)
      || (key == code_wait)
      || (key == code_space)
     ) return true;
  
  return false;
}

bool MoldorianLineWrapper::isLinebreak(int key) {
  if (
      (key == code_br)
      ) return true;
  
  return false;
}

bool MoldorianLineWrapper::isBoxClear(int key) {
  // END
  if ((key == code_wait)
      || (key == code_end)) return true;
  
  return false;
}

void MoldorianLineWrapper::onBoxFull() {
/*    std::string content;
    if (lineHasContent) {
      // wait
      content = thingy.getEntry(code_KEY);
      currentScriptBuffer.write(content.c_str(), content.size());
    }
    // linebreak
    stripCurrentPreDividers();
    
    currentScriptBuffer.put('\n');
    xPos = 0;
    yPos = 0; */
    
    if (clearMode == clearMode_default) {
      std::string content;
      if (lineHasContent) {
        // wait
        content += thingy.getEntry(code_wait);
        content += thingy.getEntry(code_br);
        currentScriptBuffer.write(content.c_str(), content.size());
      }
      // linebreak
      stripCurrentPreDividers();
      
      currentScriptBuffer.put('\n');
      xPos = 0;
      yPos = 0;
    }
    else if (clearMode == clearMode_messageSplit) {
      std::string content;
//      if (lineHasContent) {
        // wait
//        content += thingy.getEntry(code_wait);
//        content += thingy.getEntry(code_br);
        content += thingy.getEntry(code_end);
        content += "\n\n#ENDMSG()\n\n";
        currentScriptBuffer.write(content.c_str(), content.size());
//      }
      // linebreak
      stripCurrentPreDividers();
      
      xPos = 0;
      yPos = 0;
    }

//  std::cerr << "WARNING: line " << lineNum << ":" << std::endl;
//  std::cerr << "  overflow at: " << std::endl;
//  std::cerr << streamAsString(currentScriptBuffer)
//    << std::endl
//    << streamAsString(currentWordBuffer) << std::endl;

//  if (spkrOn) {
//    xPos = spkrBoxInitialX;
//  }
}

int MoldorianLineWrapper::linebreakKey() {
  return code_br;
}

void MoldorianLineWrapper::onSymbolAdded(BlackT::TStream& ifs, int key) {
/*  if (isLinebreak(key)) {
    if ((yPos != -1) && (yPos >= ySize - 1)) {
      flushActiveWord();
      
    }
  } */
}

/*void MoldorianLineWrapper::afterLinebreak(
    LinebreakSource clearSrc, int key) {
  if (clearSrc != linebreakBoxEnd) {
    if (spkrOn) {
      xPos = spkrLineInitialX;
    }
  }
} */

void MoldorianLineWrapper::beforeBoxClear(
    BoxClearSource clearSrc, int key) {
  if (((clearSrc == boxClearManual) && (key == code_wait))) {
    xBeforeWait = xPos;
  }
}

void MoldorianLineWrapper::afterBoxClear(
  BoxClearSource clearSrc, int key) {
  // wait pauses but does not automatically break the line
  if (((clearSrc == boxClearManual) && (key == code_wait))) {
    xPos = xBeforeWait;
    yPos = -1;
  }
}

bool MoldorianLineWrapper::processUserDirective(BlackT::TStream& ifs) {
  TParse::skipSpace(ifs);
  
  std::string name = TParse::matchName(ifs);
  TParse::matchChar(ifs, '(');
  
  for (int i = 0; i < name.size(); i++) {
    name[i] = toupper(name[i]);
  }
  
  if (name.compare("SETCLEARMODE") == 0) {
    std::string type = TParse::matchName(ifs);
    
    if (type.compare("DEFAULT") == 0) {
      clearMode = clearMode_default;
    }
    else if (type.compare("MESSAGESPLIT") == 0) {
      clearMode = clearMode_messageSplit;
    }
    else {
      throw TGenericException(T_SRCANDLINE,
                              "MoldorianLineWrapper::processUserDirective()",
                              "Line "
                                + TStringConversion::intToString(lineNum)
                                + ": unknown clear mode '"
                                + type
                                + "'");
    }
    
    return true;
  }
/*  else if (name.compare("PARABR") == 0) {
//    if (yPos >= ySize) {
//      onBoxFull();
//    }
//    else {
//      onBoxFull();
//    }
    flushActiveWord();
    outputLinebreak();
    return true;
  } */
//  else if (name.compare("ENDMSG") == 0) {
//    processEndMsg(ifs);
//    return true;
//  }
  
  return false;
}

}
