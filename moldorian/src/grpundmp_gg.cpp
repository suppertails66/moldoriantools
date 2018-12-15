#include "sms/SmsPattern.h"
#include "sms/OneBppCmp.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TBufStream.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "util/TStringConversion.h"
#include "util/TOpt.h"
#include <string>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Sms;

int patternsPerRow = 16;

int main(int argc, char* argv[]) {
  if (argc < 4) {
    cout << "Game Gear graphics undumper"
      << endl;
    cout << "Usage: " << argv[0] << " <infile> <outfile> <numpatterns>"
      << " [options]" << endl;
    cout << "Options:" << endl;
    cout << "  p    Specify palette file" << endl;
    return 0;
  }
  
//  TIfstream ifs(argv[1], ios_base::binary);
//  int numPatterns = TStringConversion::stringToInt(string(argv[4]));
  int numPatterns = TStringConversion::stringToInt(string(argv[3]));

  SmsPalette* palptr = NULL;
  char* palettename = TOpt::getOpt(argc, argv, "-p");
  SmsPalette pal;
  bool colorsUsed[16];
  bool colorsAvailable[16];
  if (palettename != NULL) {
    TIfstream palifs(argv[4], ios_base::binary);
    pal.readGG(palifs);
    palptr = &pal;
    for (int i = 0; i < 16; i++) {
      colorsUsed[i] = true;
      colorsAvailable[i] = true;
    }
  }
  
//  int outW = patternsPerRow * SmsPattern::w;
//  int outH = numPatterns / patternsPerRow;
//  if ((numPatterns % patternsPerRow)) ++outH;
//  outH *= SmsPattern::h;
  
  TGraphic g;
  TPngConversion::RGBAPngToGraphic(string(argv[1]), g);
  
  TBufStream buffer(0x100000);
  for (int i = 0; i < numPatterns; i++) {
    int x = (i % patternsPerRow) * SmsPattern::w;
    int y = (i / patternsPerRow) * SmsPattern::h;
  
    SmsPattern pattern;
    
    if (palptr != NULL) {
      pattern.approximateGraphic(g, *palptr, colorsUsed, colorsAvailable,
                                 x, y, false, true, true);
    }
    else {
      pattern.fromGrayscaleGraphic(g, x, y);
    }
    
    pattern.write(buffer);
  }
  
  buffer.seek(0);
  buffer.save(argv[2]);
//  TOfstream ofs(argv[2], ios_base::binary);
//  ZenkiGrpCmp::cmpZenki(buffer, ofs);
  
  
  return 0;
}
