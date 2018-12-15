#ifndef MOLDCMP_H
#define MOLDCMP_H


#include "util/TStream.h"
#include "util/TBufStream.h"

namespace Sms {

class MoldCmp {
public:
  static int cmpMold(BlackT::TStream& src, BlackT::TStream& dst);
  static void decmpMold(BlackT::TStream& src, BlackT::TStream& dst,
                        int outputSize);
protected:
  const static int minAbsoluteRun = 2;
// const static int maxAbsoluteRun = 0xFF + 1;
  const static int maxAbsoluteRun = 0x7F + 1;
  const static int maxLookbackRun = 0xF + 3;
  const static int minLookbackRun = 3;
  const static int maxLookbackDistance = 0x7FF;

  struct LookbackCommand {
    int offset;
    int length;
  };
  
  static void flushAbsoluteBuffer(BlackT::TBufStream& absoluteBuffer,
                           BlackT::TStream& dst);
  
  static LookbackCommand findBestLookback(BlackT::TStream& src);
  
};


}


#endif
