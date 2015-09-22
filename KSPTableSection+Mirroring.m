//
//  KSPTableSection+Mirroring.m
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 26.11.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPTableSection+Mirroring.h"

@implementation KSPTableSection (Mirroring)

- (NSArray<__kindof NSManagedObject*>*) mirroredNestedObjects
{
  return [self.nestedObjects reverseObjectEnumerator].allObjects;
}

@end
