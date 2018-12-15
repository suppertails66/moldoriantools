#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TThingyTable.h"
#include "util/TIniFile.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "sms/SmsPattern.h"
#include "exception/TGenericException.h"
#include <string>
#include <vector>
#include <fstream>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Sms;

const static int numChars = 0x100;
const static int charsPerRow = 16;

string as2bHex(int num) {
  string str = TStringConversion::intToString(num,
                TStringConversion::baseHex).substr(2, string::npos);
  while (str.size() < 2) str = "0" + str;
  return str;
}

void shiftPatternRight(SmsPattern& pattern, int pixelShift) {
  int startX = pixelShift;
  int endX = SmsPattern::w;
  
  SmsPattern orig = pattern;
  for (int j = 0; j < SmsPattern::h; j++) {
    for (int i = startX; i < endX; i++) {
//    for (int i = endX - 1; i >= startX; i--) {
      pattern.setData(i, j, orig.data(i - pixelShift, j));
    }
    for (int i = 0; i < startX; i++) {
      // needs to be zeroed for OR operation
      pattern.setData(i, j, 0);
    }
  }
}

void shiftPatternLeft(SmsPattern& pattern, int pixelShift) {
  int startX = 0;
  int endX = (SmsPattern::w - pixelShift);
  
  SmsPattern orig = pattern;
  for (int j = 0; j < SmsPattern::h; j++) {
    for (int i = startX; i < endX; i++) {
      pattern.setData(i, j, orig.data(i + pixelShift, j));
    }
    for (int i = endX; i < SmsPattern::w; i++) {
//      pattern.setData(i, j, 0);
      // fill right side with color of upper-right pixel, which we assume
      // is the "background" color
      pattern.setData(i, j, orig.data(7, 0));
    }
  }
}

int main(int argc, char* argv[]) {
  if (argc < 3) {
    cout << "Moldorian font builder" << endl;
    cout << "Usage: " << argv[0] << " [inprefix] [outprefix]" << endl;
    
    return 0;
  }
  
  string inPrefix = string(argv[1]);
  string outPrefix = string(argv[2]);
  
  TIniFile sizeTable;
  sizeTable.readFile((inPrefix + "sizetable.txt"));
  
  TBufStream sizeTableOfs(numChars);
  for (int i = 0; i < numChars; i++) {
    string key = as2bHex(i);
    if (sizeTable.hasKey("", key)) {
      sizeTableOfs.writeu8(
        TStringConversion::stringToInt(sizeTable.valueOfKey("", key)));
    }
    else {
      sizeTableOfs.writeu8(0x00);
    }
  }
  
  sizeTableOfs.save((outPrefix + "sizetable.bin").c_str());
  
  TGraphic g;
  TPngConversion::RGBAPngToGraphic((inPrefix + "font.png").c_str(), g);
  
  vector<TBufStream> patternRightShiftBuffers;
  vector<TBufStream> patternLeftShiftBuffers;
  patternRightShiftBuffers.resize(8);
  patternLeftShiftBuffers.resize(8);
  for (unsigned int i = 0; i < 8; i++) {
    patternRightShiftBuffers[i] = TBufStream(0x4000);
    patternLeftShiftBuffers[i] = TBufStream(0x4000);
  }
  
//  TBufStream buffer(0x100000);
  for (int i = 0; i < numChars; i++) {
    int x = (i % charsPerRow) * SmsPattern::w;
    int y = (i / charsPerRow) * SmsPattern::h;
  
    SmsPattern pattern;
    pattern.fromGrayscaleGraphic(g, x, y);
    
//    pattern.write(buffer);
    
    for (int pixelShift = 0; pixelShift < 8; pixelShift++) {
      SmsPattern shiftedPattern = pattern;
      shiftPatternRight(shiftedPattern, pixelShift);
      shiftedPattern.write(patternRightShiftBuffers[pixelShift]);
    }
    
    for (int pixelShift = 0; pixelShift < 8; pixelShift++) {
      SmsPattern shiftedPattern = pattern;
      shiftPatternLeft(shiftedPattern, pixelShift);
      shiftedPattern.write(patternLeftShiftBuffers[pixelShift]);
    }
  }
  
  std::ofstream ofs(outPrefix + "font.inc");
  
  for (int i = 0; i < 8; i++) {
    string num = as2bHex(i);
    string name = "font_rshift_" + num;
    ofs << ".slot 1" << endl;
    ofs << ".section \""
      << name << " not a fucking size specifier\" superfree" << endl;
    ofs << "  " << name << ":" << endl;
    ofs << "    .incbin \""
      << outPrefix + name + ".bin"
      << "\"" << endl;
    ofs << ".ends" << endl;
  }
  
  for (int i = 0; i < 8; i++) {
    string num = as2bHex(i);
    string name = "font_lshift_" + num;
    ofs << ".slot 1" << endl;
    ofs << ".section \""
      << name << " not a fucking size specifier\" superfree" << endl;
    ofs << "  " << name << ":" << endl;
    ofs << "    .incbin \""
      << outPrefix + name + ".bin"
      << "\"" << endl;
    ofs << ".ends" << endl;
  }
  
/*  ofs << ".bank 0 slot 0" << endl;
  ofs << ".section \"font tables\" free" << endl;
  
    ofs << "  fontRightShiftBankTbl:" << endl;
    for (int i = 0; i < 8; i++) {
      string num = as2bHex(i);
      string name = "font_rshift_" + num;
      ofs << "    .db :" << name << endl;
    }
    
    ofs << "  fontRightShiftPtrTbl:" << endl;
    for (int i = 0; i < 8; i++) {
      string num = as2bHex(i);
      string name = "font_rshift_" + num;
      ofs << "    .dw " << name << endl;
    }
  
    ofs << "  fontLeftShiftBankTbl:" << endl;
//    for (int i = 7; i >= 0; i--) {
    for (int i = 0; i < 8; i++) {
      string num = as2bHex(i);
      string name = "font_lshift_" + num;
      ofs << "    .db :" << name << endl;
    }
    
    ofs << "  fontLeftShiftPtrTbl:" << endl;
//    for (int i = 7; i >= 0; i--) {
    for (int i = 0; i < 8; i++) {
      string num = as2bHex(i);
      string name = "font_lshift_" + num;
      ofs << "    .dw " << name << endl;
    }
  
  ofs << ".ends" << endl; */
  
  for (int i = 0; i < 8; i++) {
    string num = as2bHex(i);
    patternRightShiftBuffers[i].save(
      (outPrefix + "font_rshift_" + num + ".bin").c_str());
    patternLeftShiftBuffers[i].save(
      (outPrefix + "font_lshift_" + num + ".bin").c_str());
    
  }
  
  return 0;
}

