#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TThingyTable.h"
#include "moldorian/MoldorianScriptReader.h"
#include "moldorian/MoldorianLineWrapper.h"
#include "exception/TGenericException.h"
#include <string>
#include <map>
#include <fstream>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Sms;

TThingyTable table;

const static int hashMask = 0x1FFF;

const static int op_br   = 0x90;
const static int op_wait = 0x91;
const static int op_hero = 0x92;
const static int op_op93 = 0x93;
const static int op_terminator = 0xFF;

string getStringName(MoldorianScriptReader::ResultString result) {
//  int bankNum = result.srcOffset / 0x4000;
  return string("string_")
    + TStringConversion::intToString(result.srcOffset,
          TStringConversion::baseHex);
}

void exportRawResults(MoldorianScriptReader::ResultCollection& results,
                      std::string filename) {
  TBufStream ofs(0x10000);
  for (int i = 0; i < results.size(); i++) {
    ofs.write(results[i].str.c_str(), results[i].str.size());
  }
  ofs.save((filename).c_str());
}

void exportRawResults(TStream& ifs,
                      std::string filename) {
  MoldorianScriptReader::ResultCollection results;
  MoldorianScriptReader(ifs, results, table)();
  exportRawResults(results, filename);
}

void exportSizeTabledResults(TStream& ifs,
                         std::string binFilename) {
  MoldorianScriptReader::ResultCollection results;
  MoldorianScriptReader(ifs, results, table)();
  
//  std::ofstream incofs(incFilename.c_str());
  TBufStream ofs(0x10000);
  ofs.writeu8(results.size());
  
  int offset = 0;
  for (int i = 0; i < results.size(); i++) {
    ofs.writeu16le(offset + (results.size() * 2));
    offset += results[i].str.size();
  }
  
  for (int i = 0; i < results.size(); i++) {
    ofs.write(results[i].str.c_str(), results[i].str.size());
  }
  
  ofs.save((binFilename).c_str());
}

int main(int argc, char* argv[]) {
  if (argc < 4) {
    cout << "Moldorian script builder" << endl;
    cout << "Usage: " << argv[0] << " [inprefix] [thingy] [outprefix]"
      << endl;
    
    return 0;
  }
  
  string inPrefix = string(argv[1]);
  string tableName = string(argv[2]);
  string outPrefix = string(argv[3]);
  
  table.readSjis(tableName);
  
  // wrap script
  {
    // read size table
    MoldorianLineWrapper::CharSizeTable sizeTable;
    {
      TBufStream ifs;
      ifs.open("out/font/sizetable.bin");
      int pos = 0;
      while (!ifs.eof()) {
        sizeTable[pos++] = ifs.readu8();
      }
    }
    
    {
      TBufStream ifs;
      ifs.open((inPrefix + "script.txt").c_str());
      
      TLineWrapper::ResultCollection results;
      MoldorianLineWrapper(ifs, results, table, sizeTable)();
      
      if (results.size() > 0) {
        TOfstream ofs((outPrefix + "script_wrapped.txt").c_str());
        ofs.write(results[0].str.c_str(), results[0].str.size());
      }
    }
    
    {
      TBufStream ifs;
      ifs.open((inPrefix + "manual_ingame.txt").c_str());
      
      TLineWrapper::ResultCollection results;
      MoldorianLineWrapper(ifs, results, table, sizeTable)();
      
      if (results.size() > 0) {
        TOfstream ofs((outPrefix + "manual_ingame_wrapped.txt").c_str());
        ofs.write(results[0].str.c_str(), results[0].str.size());
      }
    }
  }
  
  // remapped strings
  {
    TBufStream ifs;
//    ifs.open((inPrefix + "script.txt").c_str());
    ifs.open((outPrefix + "script_wrapped.txt").c_str());
    
    MoldorianScriptReader::ResultCollection results;
    MoldorianScriptReader(ifs, results, table)();
    
//    TBufStream ofs(0x20000);
//    for (unsigned int i = 0; i < results.size(); i++) {
//      ofs.write(results[i].str.c_str(), results[i].str.size());
//    }
//    ofs.save((outPrefix + "script.bin").c_str());
    
    // create:
    // * an individual .bin file for each compiled string
    // * a .inc containing, for each string, one superfree section with an
    //   incbin that includes the corresponding string's .bin
    // * a .inc containing the hash bucket arrays for the remapped strings.
    //   table keys are (orig_pointer & 0x1FFF).
    //   the generated bucket sets go in a single superfree section.
    //   each bucket set is an array of the following structure (terminate
    //   arrays with FF so we can detect missed entries):
    //       struct Bucket {
    //       u8 origBank
    //       u16 origPointer  // respects original slotting!
    //       u8 newBank
    //       u16 newPointer
    //     }
    // * a .inc containing the bucket array start pointers (keys are 16-bit
    //   and range from 0x0000-0x1FFF, so this gets its own bank)
    
    std::ofstream strIncOfs((outPrefix + "strings.inc").c_str());
    std::map<int, MoldorianScriptReader::ResultCollection>
      mappedStringBuckets;
    for (unsigned int i = 0; i < results.size(); i++) {
      std::string stringName = getStringName(results[i]);
      
      // write string to file
      TBufStream ofs(0x10000);
      ofs.write(results[i].str.c_str(), results[i].str.size());
      ofs.save((outPrefix + "strings/" + stringName + ".bin").c_str());
      
      // add string binary to generated includes
      strIncOfs << ".slot 1" << endl;
      strIncOfs << ".section \"string include " << i << "\" superfree"
        << endl;
      strIncOfs << "  " << stringName << ":" << endl;
      strIncOfs << "    " << ".incbin \""
        << outPrefix << "strings/" << stringName << ".bin"
        << "\"" << endl;
      strIncOfs << ".ends" << endl;
      
      // add to map
      mappedStringBuckets[results[i].srcOffset & hashMask]
        .push_back(results[i]);
    }
    
    // generate bucket arrays
    std::ofstream stringHashOfs(
      (outPrefix + "string_bucketarrays.inc").c_str());
    stringHashOfs << ".include \""
      << outPrefix + "strings.inc\""
      << endl;
    stringHashOfs << ".section \"string hash buckets\" superfree" << endl;
    stringHashOfs << "  stringHashBuckets:" << endl;
    for (std::map<int, MoldorianScriptReader::ResultCollection>::iterator it
           = mappedStringBuckets.begin();
         it != mappedStringBuckets.end();
         ++it) {
      int key = it->first;
      MoldorianScriptReader::ResultCollection& results = it->second;
      
      stringHashOfs << "  hashBucketArray_"
        << TStringConversion::intToString(key,
              TStringConversion::baseHex)
        << ":" << endl;
      
      for (unsigned int i = 0; i < results.size(); i++) {
        MoldorianScriptReader::ResultString result = results[i];
        string stringName = getStringName(result);
        
        // original bank
        stringHashOfs << "    .db " << result.srcOffset / 0x4000 << endl;
        // original pointer (respecting slotting)
        stringHashOfs << "    .dw "
          << (result.srcOffset & 0x3FFF) + (0x4000 * result.srcSlot)
          << endl;
        // new bank
        stringHashOfs << "    .db :" << stringName << endl;
        // new pointer
        stringHashOfs << "    .dw " << stringName << endl;
      }
      
      // array terminator
      stringHashOfs << "  .db $FF " << endl;
    }
    stringHashOfs << ".ends" << endl;
    
    // generate bucket array hash table
    std::ofstream bucketHashOfs(
      (outPrefix + "string_bucket_hashtable.inc").c_str());
    bucketHashOfs << ".include \""
      << outPrefix + "string_bucketarrays.inc\""
      << endl;
    bucketHashOfs
      << ".section \"bucket array hash table\" size $4000 align $4000 superfree"
      << endl;
    bucketHashOfs << "  bucketArrayHashTable:" << endl;
    for (int i = 0; i < hashMask; i++) {
      std::map<int, MoldorianScriptReader::ResultCollection>::iterator findIt
        = mappedStringBuckets.find(i);
      if (findIt != mappedStringBuckets.end()) {
        int key = findIt->first;
        bucketHashOfs << "    .dw hashBucketArray_"
        << TStringConversion::intToString(key,
              TStringConversion::baseHex)
        << endl;
      }
      else {
        // no array
        bucketHashOfs << "    .dw $FFFF" << endl;
      }
    }
    bucketHashOfs << ".ends" << endl;
  }
  
  // hero default name
  {
    TBufStream ifs;
    ifs.open((inPrefix + "hero_default_name.txt").c_str());
    
    MoldorianScriptReader::ResultCollection results;
    MoldorianScriptReader(ifs, results, table)();
    
    if (results.size() > 0) {
      TBufStream ofs(0x10000);
      ofs.write(results[0].str.c_str(), results[0].str.size());
      ofs.save((outPrefix + "hero_default_name.bin").c_str());
    }
  }
  
  // name entry character table
  {
    TBufStream ifs;
    ifs.open((inPrefix + "name_entry_chartable.txt").c_str());
    
    MoldorianScriptReader::ResultCollection results;
    MoldorianScriptReader(ifs, results, table)();
    
    if (results.size() > 0) {
      TBufStream ofs(0x10000);
      ofs.write(results[0].str.c_str(), results[0].str.size());
      ofs.save((outPrefix + "name_entry_chartable.bin").c_str());
    }
  }
  
  // intro
  {
    TBufStream ifs;
    ifs.open((inPrefix + "intro.txt").c_str());
    
    exportRawResults(ifs, outPrefix + "intro.bin");
  }
  
  // name confirmation message
  {
    TBufStream ifs;
    ifs.open((inPrefix + "name_entry_confirmation.txt").c_str());
    
    exportRawResults(ifs, outPrefix + "name_entry_confirmation.bin");
  }
  
  // plural enemy names
  {
    TBufStream ifs;
    ifs.open((inPrefix + "enemy_names_plural.txt").c_str());
    
    exportSizeTabledResults(ifs, outPrefix + "enemy_names_plural.bin");
  }
  
  // plural curse count
  {
    TBufStream ifs;
    ifs.open((inPrefix + "curse_count_plural.txt").c_str());
    
//    exportRawResults(ifs, outPrefix + "curse_count_plural.bin");

    MoldorianScriptReader::ResultCollection results;
    MoldorianScriptReader(ifs, results, table)();
    exportRawResults(results, outPrefix + "curse_count_plural_1.bin");
    
    results = MoldorianScriptReader::ResultCollection();
    MoldorianScriptReader(ifs, results, table)();
    exportRawResults(results, outPrefix + "curse_count_plural_2.bin");
  }
  
  // user manual
  {
    TBufStream ifs;
    ifs.open((outPrefix + "manual_ingame_wrapped.txt").c_str());
    
    // label for main menu
    exportRawResults(ifs, outPrefix + "manual_menulabel.bin");
    
    // table of contents menu
    exportSizeTabledResults(ifs, outPrefix + "manual_index.bin");
    
    // intro
    exportRawResults(ifs, outPrefix + "manual_intro.bin");
    
    // prologue
//    exportSizeTabledResults(ifs, outPrefix + "manual_section0.bin");
    // main characters
//    exportSizeTabledResults(ifs, outPrefix + "manual_section1.bin");
    
    for (int i = 0; i < 8; i++) {
      exportSizeTabledResults(ifs, outPrefix + "manual_section"
                                    + TStringConversion::intToString(i)
                                    + ".bin");
    }
  }
  
  // translation credits
  {
    TBufStream ifs;
    ifs.open((inPrefix + "translation_credits.txt").c_str());
    
    // label for main menu
    exportRawResults(ifs, outPrefix + "credits_menulabel.bin");
    
    // prologue
//    exportSizeTabledResults(ifs, outPrefix + "manual_section0.bin");
    // main characters
//    exportSizeTabledResults(ifs, outPrefix + "manual_section1.bin");
    
    exportSizeTabledResults(ifs, outPrefix + "translation_credits.bin");
  }
  
  return 0;
}

