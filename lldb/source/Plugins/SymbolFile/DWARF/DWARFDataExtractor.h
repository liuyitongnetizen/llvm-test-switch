//===-- DWARFDataExtractor.h ------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLDB_SOURCE_PLUGINS_SYMBOLFILE_DWARF_DWARFDATAEXTRACTOR_H
#define LLDB_SOURCE_PLUGINS_SYMBOLFILE_DWARF_DWARFDATAEXTRACTOR_H

#include "lldb/Utility/DataExtractor.h"
#include "llvm/DebugInfo/DWARF/DWARFDataExtractor.h"

namespace lldb_private {

class DWARFDataExtractor : public DataExtractor {
public:
  DWARFDataExtractor() = default;

  DWARFDataExtractor(const DWARFDataExtractor &data, lldb::offset_t offset,
                     lldb::offset_t length)
      : DataExtractor(data, offset, length) {}

  llvm::DWARFDataExtractor GetAsLLVMDWARF() const;
  llvm::DataExtractor GetAsLLVM() const;
};
} // namespace lldb_private

#endif // LLDB_SOURCE_PLUGINS_SYMBOLFILE_DWARF_DWARFDATAEXTRACTOR_H
