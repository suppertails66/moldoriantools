#include "util/TFreeSpace.h"
#include "util/TIniFile.h"
#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include <vector>
#include <sstream>
#include <iostream>

using namespace std;
using namespace BlackT;

int nextInt(istream& ifs) {
  string str;
  ifs >> str;
  return TStringConversion::stringToInt(str);
}

struct DataDefinition {
  std::string name;
  int address;
  int pointer;
  int bank;
  int slot;
  int size;
};

int main(int argc, char* argv[]) {
  
  
  if (argc < 6) {
    cout << "Data injection utility" << endl;
    cout << "Usage: " << argv[0] << " <spacefile> <scriptfile> <src> <dst>"
      << " <defdst>"
      << endl;
    
    return 0;
  }
  
 TFreeSpace freeSpace;
 freeSpace.setBoundarySize(0x4000);
  
/*  freeSpace.free(0x4300, 0x0100);
  freeSpace.free(0x4400, 0x0100);
  freeSpace.free(0x4500, 0x0100); */
  
  TBufStream ofs(0x800000);
  {
    TIfstream ifs(argv[3], ios_base::binary);
    ofs.writeFrom(ifs, ifs.size());
  }
  int romSize = ofs.tell();
  
  TIniFile freeSpaceFile(argv[1]);
  
  for (SectionKeysMap::const_iterator it = freeSpaceFile.cbegin();
       it != freeSpaceFile.cend();
       ++it) {
    int pos = TStringConversion::stringToInt(it->first);
    int size = TStringConversion::stringToInt(
      freeSpaceFile.valueOfKey(it->first, "size"));
    freeSpace.free(pos, size);
  }
  
/*  for (TFreeSpace::FreeSpaceMap::iterator it = freeSpace.freeSpace_.begin();
       it != freeSpace.freeSpace_.end();
       ++it) {
    std::cout << std::hex << it->first << " " << std::hex << it->second << std::endl;
  }
  
  return 0; */
  
  std::vector<DataDefinition> dataDefinitions;
  
  TIniFile scriptFile(argv[2]);
  
  for (SectionKeysMap::const_iterator it = scriptFile.cbegin();
       it != scriptFile.cend();
       ++it) {
    string sourceFile = scriptFile.valueOfKey(it->first, "source");
    int origPos = TStringConversion::stringToInt(
      scriptFile.valueOfKey(it->first, "origPos"));
    int origSize = TStringConversion::stringToInt(
      scriptFile.valueOfKey(it->first, "origSize"));
      
    vector<int> pointers;
    if (scriptFile.hasKey(it->first, "pointers")) {
      string pointersString = scriptFile.valueOfKey(it->first, "pointers");
      istringstream iss(pointersString);
//      cerr << pointersString << endl;
      while (iss.good()) {
//        iss.get();
//        iss.unget();
        
        int ptr = nextInt(iss);
//        if (!iss.good()) break;
        pointers.push_back(ptr);
//        cerr << std::hex << ptr << endl;
      }
    }
      
    vector<int> banks;
    if (scriptFile.hasKey(it->first, "banks")) {
      string banksString = scriptFile.valueOfKey(it->first, "banks");
      istringstream iss(banksString);
      while (iss.good()) {
        int bank = nextInt(iss);
        banks.push_back(bank);
      }
    }
    
    vector<int> sizes16;
    if (scriptFile.hasKey(it->first, "rawSize16")) {
      string sizesString = scriptFile.valueOfKey(it->first, "rawSize16");
      istringstream iss(sizesString);
      while (iss.good()) {
        int sz = nextInt(iss);
        sizes16.push_back(sz);
//        cout << ptr << endl;
      }
    }
    
    TIfstream ifs(sourceFile.c_str(), ios_base::binary);
    int newSize = ifs.size();
    // word-align inserted data
    int claimSize = newSize + (newSize % 2);
    
    int newPos = origPos;
    // compute bank limits
    int bankNum = origPos / 0x4000;
    int bankLow = bankNum * 0x4000;
    
    bool bankLocked = false;
    if (scriptFile.hasKey(it->first, "bankLocked")) {
      bankLocked = (TStringConversion::stringToInt(
        scriptFile.valueOfKey(it->first, "bankLocked")) != 0);
    }
    
    // Put at original position if possible
    if (newSize <= origSize) {
      ofs.seek(origPos);
      ofs.writeFrom(ifs, newSize);
      
      cout << sourceFile << ": overwrote at 0x"
        << hex << origPos << dec << endl;
    }
    // Relocate if larger than original size
    else {
//      int bankHigh = bankLow + 0x4000;
//      std::cerr << bankLow << std::endl;
    
      if (bankLocked) {
        // Try to find new position within original bank
        newPos = freeSpace.claim(claimSize, bankLow, bankLow + 0x4000);
      }
      else {
        newPos = freeSpace.claim(claimSize, 0, 0x100000);
      }
      
      // If we can't get that much space, try using the fixed bank
      if (newPos == -1) {
        newPos = freeSpace.claim(claimSize, 0, 0 + 0x8000);
        
        if (newPos == -1) {
          // If we still can't get enough space, error
          cerr << "Error injecting " << sourceFile << ": can't find "
            << claimSize << " bytes of free space" << endl;
          return 1;
        }
        
        bankNum = 0;
      }
      
      // Insert at new position
      ofs.seek(newPos);
      ofs.writeFrom(ifs, newSize);
      
      // Update ROM size if necessary
      if (ofs.tell() > romSize) romSize = ofs.tell();
      
      // Free up original space for other content
      freeSpace.free(origPos, origSize);
      
      cout << sourceFile << ": moved from 0x"
        << hex << origPos << " to 0x"
        << newPos << dec << endl;
    }
    
    // Regardless of whether we actually moved the data, update
    // pointers, etc. -- we may actually be inserting new pointers
    // for added code to reference
  
    // Update pointers
    int slotNum = TStringConversion::stringToInt(
      scriptFile.valueOfKey(it->first, "slot"));
    
    // If inserted into either fixed bank, use corresponding slot
    int newPtr = newPos % 0x4000;
//    if ((bankNum == 0) || (bankNum == 1)) {
//      
//    }
//    // Otherwise, use specified slot
//    else {
      newPtr += (slotNum * 0x4000);
//    }
    
    int newBank = newPos / 0x4000;
    
    for (unsigned int i = 0; i < pointers.size(); i++) {
      ofs.seek(pointers[i]);
      ofs.writeu16le(newPtr);
    }
    
    // Update bank numbers
    for (unsigned int i = 0; i < banks.size(); i++) {
      ofs.seek(banks[i]);
      ofs.writeu8(newBank);
    }
    
    // Update size references
    if (sizes16.size() != 0) {
      int rawFileSize;
      {
        string rawSourceFile = scriptFile.valueOfKey(it->first, "rawSource");
        TIfstream rawifs(rawSourceFile.c_str(), ios_base::binary);
        rawFileSize = rawifs.size();
      }
      
      for (unsigned int i = 0; i < sizes16.size(); i++) {
        ofs.seek(sizes16[i]);
        ofs.writeu16be(rawFileSize);
      }
      
    }
    
    DataDefinition def;
    def.name = it->first;
    def.address = newPos;
    def.pointer = newPtr;
    def.bank = newBank;
    def.slot = slotNum;
    def.size = claimSize;
    dataDefinitions.push_back(def);
  }
  
  ofs.seek(romSize);
  ofs.save(argv[4]);
  
  // export definition sheets for use by script assembler
  {
    std::ofstream ofs(argv[5], ios_base::binary);
    for (unsigned int i = 0; i < dataDefinitions.size(); i++) {
      DataDefinition def = dataDefinitions[i];
      ofs << ";===============================" << std::endl;
      ofs << "; " << def.name << std::endl;
      ofs << ";===============================" << std::endl;
      ofs << ".define " << def.name << " " << def.pointer << endl;
      ofs << ".define " << def.name << "_addr " << def.address << endl;
      ofs << ".define " << def.name << "_bank " << def.bank << endl;
      ofs << ".define " << def.name << "_size " << def.size << endl;
      
      ofs << endl << endl;
    }
  }
  
  return 0;
}

