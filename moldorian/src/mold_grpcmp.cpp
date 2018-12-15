#include "sms/SmsPattern.h"
#include "sms/MoldCmp.h"
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
  if (argc < 3) {
    cout << "Moldorian graphics compressor"
      << endl;
    cout << "Usage: " << argv[0] << " <infile> <outfile>"
      << endl;
    return 0;
  }
  
  TBufStream ifs(0x10000);
  ifs.open(argv[1]);
  TBufStream ofs(0x10000);
  MoldCmp::cmpMold(ifs, ofs);
  
  std::cout << "File: " << argv[1] << std::endl;
  std::cout << "  Compressed size: " << ofs.tell()
    << " bytes" << std::endl;
  
  ofs.save(argv[2]);
  
/*  TIfstream ifs(argv[1], ios_base::binary);
  TBufStream buffer(0x100000);
  MkrGGGrpCmp::cmpMkrGG(ifs, buffer);
  buffer.seek(0);
  TOfstream ofs(argv[2], ios_base::binary);
  ofs.write(buffer.data().data(), buffer.size()); */
  
  return 0;
}
