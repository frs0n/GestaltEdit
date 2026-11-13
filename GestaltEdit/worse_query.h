//
//  worse_query.h
//  worse_query
//
//  Created by Taj C on 8/20/26.
//

/*
     worse_query - A sandbox escape PoC for iOS 26 and 27, again.
     Copyright (C) 2026 Taj C (forcequit)

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef worse_query_h
#define worse_query_h

#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdbool.h>

// Negative results: -1 group unavailable, -2 missing APIs, -3 query allocation,
// -4 cache setup, -5 query rejected, -6 no token, -7 token activation,
// -8 cache restoration (original contents retained), -255 target unavailable.
// errno describes filesystem failures and failed token activation.
int64_t worse_query(NSString *path, NSString *group, bool alt_flags, bool create_dir);
void worse_query_release(int64_t handle);

#endif /* worse_query_h */
