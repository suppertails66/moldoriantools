#include "util/TBufStream.h"
#include "util/TStringConversion.h"
#include "util/TOpt.h"
#include <iostream>

using namespace std;
using namespace BlackT;

int main(int argc, char* argv[]) {
  if (argc < 5) {
    cout << "Binary file patcher" << endl;
    cout << "Usage: " << argv[0] << " <infile> <offset> <patch> <outfile>"
      << " [options]" << endl;
    cout << "Options: " << endl;
    cout << "  l   Sets maximum size of patch file; an error occurs if it"
         << endl
         << "      exceeds this size" << endl;
    
    return 0;
  }
  
  char* infile = argv[1];
  int offset = TStringConversion::stringToInt(string(argv[2]));
  char* patchfile = argv[3];
  char* outfile = argv[4];
  
  cout << "Patching " << infile << " at " << offset << " with "
    << patchfile << ", to " << outfile << endl;
  
  int maxPatchSize = -1;
  TOpt::readNumericOpt(argc, argv, "-l", &maxPatchSize);
  
  TBufStream file(1);
  file.open(infile);
  
  TBufStream patch(1);
  patch.open(patchfile);
  
  if ((maxPatchSize != -1)
      && (patch.size() > maxPatchSize)) {
    cerr << "Error: patch file is too large (max " << maxPatchSize
      << ", actual " << patch.size() << ")" << endl;
    return 1;
  }
  
  int endOffset = offset + patch.size();
  if (endOffset > file.capacity()) {
    file.setCapacity(endOffset);
  }
  
  file.seek(offset);
  patch.seek(0);
  file.write((char*)patch.data().data(), patch.size());
  
  file.save(outfile);
  
  return 0;
}
