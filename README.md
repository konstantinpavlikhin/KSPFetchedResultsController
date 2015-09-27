## KSPFetchedResultsController

The most advanced [`NSFetchedResultsController`](https://developer.apple.com/library/ios/documentation/CoreData/Reference/NSFetchedResultsController_Class) reimplementation for a desktop Cocoa.

Imagine you have a problem and you want to use CoreData. Congratulations, now you have two problems 😂.

## Rationale

CoreData was introduced in 10.4 Tiger (in 2005) and for years developers built AppKit application using one of these two mediating controllers:

### [NSArrayController](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSArrayController_Class)
There is definitely a case to use an `NSArrayController` with a CoreData (if your requirements to interactivity are pretty simple).

### [NSTreeController](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSTreeController_Class)
`NSTreeController` is [completely broken](http://blog.wilshipley.com/2006/04/pimp-my-code-part-10-whining-about.html) and should die in fire.

My personal complains about `NSTreeController` are the following:
* usage of an opaque undocumented shadow objects that wrap actual passed-in objects
* no granular `NSOutlineView` change management
* no option to bind an `NSPredicate` for items filtering
* extremely poor performance on large datasets

I tried to use this nonsense many times and failed.

In OS X 10.7 Lion `NSTableView/NSOutlineView` classes were seriously reengineered. They started to allow `NSView`-based cells instead of the ugly and extremely inconvenient `NSCell`-based ones. The second most important change was the ability to make incremental changes to the represented data set (insert rows/move rows/remove rows/update rows) and animate the corresponding transitions. All these changes made `NSTableView/NSOutlineView` pair behave and appear more like a `UITableView` from the UIKit. Unfortunately, the existing controller objects (`NSArrayController` and `NSTreeController`) were not updated to take advantage of the latest enhancements. If there is a change in the model the `NSObjectController` descendants simply reload all the table via the `-reloadData` method. For me this feels like a rude, redundant and inelegant solution with a potentially poor performance (if you have a table with a variable row heights the table will drop the cache and re-query heights for **every** row, even the invisible ones). The only option to use the new table view's features was to get rid of these glue-objects and handle the tables in a manual fashion.

For some reason Apple decided not to port the `NSFetchedResultsController` to the OS X. Given the Apple's bad habit not to fix even the most ridiculous bugs this tiny issue with a lacking fetched results controller doesn't surprise me at all.

## Let's design our very own fetched results controller

The original `NSFetchedResultsController` was designed to run on iOS and bake the `UITableView` instance. Given the fact how different `UITableView`'s API is compared to the AppKit's `NSTableView` we can't just simply copy-paste the class interface and write the FRC implementation. There is no way to create a useful drop-in component. Instead we have to port the basic idea and integrate it into existing AppKit's infrastructure.

The most drastic difference between the `NSTableView` and `UITableView` is that the latter has a concept of table sections. The `UITableView` 'asks' its delegate to return an object located at a particular index path. `NSTableView`, at most, can only show a so-called group rows, but the underlying model still have to be flat (`NSArray`). Luckily, we can use a `NSOutlineView` (which allows arbitrary items nesting) to emulate sections. `NSOutlineView` doesn't operate on index paths, instead it uses a concept of items, that can be child of some other items. This means we need a special kind of item that will represent a section in the outline view. That's what `KSPTableSection` is for.

So, whats the quintessence?
* instead of making a one huge universal fetched results controller make two: one aimed to use with a flat objects backing store for `NSTableView` and one with sectioning support with a hierarchical backing store for `NSOutlineView`.
* ditch the `NSFetchedResultsController` index paths concept, because `NSOutlineView` uses a completely different API (`-numberOfChildrenOfItem:/-child:ofItem:`).
* make the output fetched results controller collections fully collection-KVO-compatible, because this is how proper Cocoa apps™ are made.

## KSPFetchedResultsController

This class was designed to use with a `NSTableView` data source.

You instantiate a `KSPFetchedResultsController` instance with a fetch request and a managed object context. When there is a time you perform a fetch and FRC's `fetchedObjects` property gets populated with `NSManagedObjects`. Fetch results controller listens to the context did change notifications and updates its `fetchedObjects` collection in a collection-KVO-compatible way. To issue a granular updates to the `NSTableView` you have to become a delegate of the fetched results controller and implement the `KSPFetchedResultsControllerDelegate` protocol in your controller object (most probably it will be a custom `NSViewController` subclass).

This typically looks like this:

```objective-c
#pragma mark - KSPFetchedResultsControllerDelegate Implementation

- (void) controllerWillChangeContent: (KSPFetchedResultsController*) controller
{
  [self.tableView beginUpdates];
}

- (void) controller: (KSPFetchedResultsController*) controller didChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex
{
  switch(type)
  {
    case KSPFetchedResultsChangeInsert:
    {
      [self.tableView insertRowsAtIndexes: [NSIndexSet indexSetWithIndex: newIndex] withAnimation: NSTableViewAnimationEffectNone];

      break;
    }

    case KSPFetchedResultsChangeDelete:
    {
      [self.tableView removeRowsAtIndexes: [NSIndexSet indexSetWithIndex: index] withAnimation: NSTableViewAnimationEffectNone];

      break;
    }

    case KSPFetchedResultsChangeMove:
    {
      [self.tableView moveRowAtIndex: index toIndex: newIndex];

      break;
    }

    case KSPFetchedResultsChangeUpdate:
    {
      {{
        NSIndexSet* rowIndexes = [NSIndexSet indexSetWithIndex: index];

        NSIndexSet* columnIndexes = [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, self.tableView.tableColumns.count)];

        [self.tableView reloadDataForRowIndexes: rowIndexes columnIndexes: columnIndexes];
      }}

      break;
    }
  }
}

- (void) controllerDidChangeContent: (KSPFetchedResultsController*) controller
{
  [self.tableView endUpdates];
}
```

## KSPSectionedFetchedResultsController

This class was designed to use with a `NSOutlineView` data source.

`KSPSectionedFetchedResultsController` inherits from `KSPFetchedResultsController` and adds section management features to the latter.

Just like with a `KSPFetchedResultsController` you instantiate a `KSPSectionedFetchedResultsController` instance with a fetch request and a managed object context. Additionally you have to supply a section name key path that will be used to split objects into groups. When there is a time you perform a fetch and SFRC's `sections` property gets populated with `KSPTableSection` instances. Fetch results controller listens to the context did change notifications and updates its `sections` collection in a collection-KVO-compatible way. To issue a granular updates to the `NSOutlineView` you have to become a delegate of the sectioned fetched results controller and implement the `KSPSectionedFetchedResultsControllerDelegate` protocol in your controller object (most probably it will be a custom `NSViewController` subclass).

This typically looks like this:

```objective-c
#pragma mark - KPSectionedFetchedResultsControllerDelegate Implementation

- (void) controllerWillChangeContent: (KSPFetchedResultsController*) controller
{
  [self.outlineView beginUpdates];
}

- (void) controller: (KSPSectionedFetchedResultsController*) controller didChangeObject: (NSManagedObject*) anObject atIndex: (NSUInteger) index inSection: (KSPTableSection*) section forChangeType: (KSPFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex inSection: (KSPTableSection*) newSection
{
  switch(type)
  {
    case KSPFetchedResultsChangeInsert:
    {
      [self.outlineView insertItemsAtIndexes: [NSIndexSet indexSetWithIndex: newIndex] inParent: newSection withAnimation: NSTableViewAnimationEffectNone];

      break;
    }
    
    case KSPFetchedResultsChangeDelete:
    {
      [self.outlineView removeItemsAtIndexes: [NSIndexSet indexSetWithIndex: index] inParent: section withAnimation: NSTableViewAnimationEffectFade];
      
      break;
    }
    
    case KSPFetchedResultsChangeMove:
    {
      [self.outlineView moveItemAtIndex: index inParent: section toIndex: newIndex inParent: newSection];

      break;
    }

    case KSPFetchedResultsChangeUpdate:
    {
      [self.outlineView reloadItem: anObject reloadChildren: NO];
      
      break;
    }
  }
}

- (void) controller: (KSPSectionedFetchedResultsController*) controller didChangeSection: (KSPTableSection*) section atIndex: (NSUInteger) index forChangeType: (KSPSectionedFetchedResultsChangeType) type newIndex: (NSUInteger) newIndex
{
  switch(type)
  {
    case KSPSectionedFetchedResultsChangeInsert:
    {
      [self.outlineView insertItemsAtIndexes: [NSIndexSet indexSetWithIndex: newIndex] inParent: nil withAnimation: NSTableViewAnimationEffectNone];
      
      break;
    }
    
    case KSPSectionedFetchedResultsChangeDelete:
    {
      [self.outlineView removeItemsAtIndexes: [NSIndexSet indexSetWithIndex: index] inParent: nil withAnimation: NSTableViewAnimationEffectNone];
      
      break;
    }
    
    case KSPSectionedFetchedResultsChangeMove:
    {
      [self.outlineView moveItemAtIndex: index inParent: nil toIndex: newIndex inParent: nil];
      
      break;
    }
  }
}

- (void) controllerDidChangeContent: (KSPFetchedResultsController*) controller
{
  [self.outlineView endUpdates];
}
```

## KSPMirroredSectionedFetchedResultsController

This class was designed to use with a `NSOutlineView` data source.

`KSPMirroredSectionedFetchedResultsController` inherits from `KSPSectionedFetchedResultsController`. Its sole responsibility is to reverse the sort order of nested objects. This can be more efficient and logical in some cases when you implement a "pull to load more" feature in your `NSOutlineView`.

## Things that are intentionally left out

`KSPFetchedResultsController` doesn't have any notion of cache concept, that is present in `NSFetchedResultsController`.

`KSPFetchedResultsController` also doesn't have a concept of 'modes of operation' that is implemented in `NSFetchedResultsController`.

## Known issues

`NSFetchedResultsController` has a long-running defect (or feature?) that arises when you play with a `fetchLimit` and `fetchOffset` properties of a `NSFetchRequest`. For example, when you ask a CoreData store to fetch objects sorted by a particular criteria with an offset of 10 and a limit of 10 you initially get a right things. But just after a new `NSManagedObject` is inserted into the context and it passes the predicate it gets immediately reported to the FRC's delegate as inserted, though it potentially doesn't belong to the 'window' of 10 objects skipping the 10 more from the beginning.

`KSPFetchedResultsController` follows this questionable behaviour in order to be compatible with the iOS FRC version.

That's it! Let me know what you thing about it.
