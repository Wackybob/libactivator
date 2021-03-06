#import <Preferences/Preferences.h>
#import <QuartzCore/QuartzCore.h>

#import "libactivator.h"
#import "libactivator-private.h"

static LAActivator *activator;

@interface ActivatorTableViewController : PSViewController<UITableViewDataSource, UITableViewDelegate> {
@private
	UITableView *_tableView;
}

@end

@implementation ActivatorTableViewController

+ (void)load
{
	activator = [LAActivator sharedInstance];
}

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size])) {
		CGRect frame;
		frame.origin = CGPointZero;
		frame.size = size;
		_tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
		[_tableView setRowHeight:60.0f];
		[_tableView setDataSource:self];
		[_tableView setDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[_tableView setDelegate:nil];
	[_tableView setDataSource:nil];
	[_tableView release];
	[super dealloc];
}

- (UIView *)view
{
	return _tableView;
}

- (UITableView *)tableView
{
	return _tableView;
}

- (CGSize)contentSize
{
	return [_tableView frame].size;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)pushController:(id<PSBaseView>)controller
{
	//[[self parentController] pushController:controller];
	[super pushController:controller];
	[controller setParentController:self];
}

@end

@interface ActivatorEventViewHeader : UIView {
@private
	NSString *_listenerName;
}

@property (nonatomic, copy) NSString *listenerName;

@end

@implementation ActivatorEventViewHeader

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[self setOpaque:YES];
		[self setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	}
	return self;
}

- (NSString *)listenerName
{
	return _listenerName;
}

- (void)setListenerName:(NSString *)listenerName
{
	if (![_listenerName isEqualToString:listenerName]) {
		[_listenerName release];
		_listenerName = [listenerName copy];
		[self setNeedsDisplay];
		CATransition *animation = [CATransition animation];
		[animation setType:kCATransitionFade];
		//[animation setDuration:0.3];
		[[self layer] addAnimation:animation forKey:kCATransition];
	}
}

- (void)drawRect:(CGRect)rect
{
	[[UIColor tableSeparatorDarkColor] setFill];
	CGContextRef c = UIGraphicsGetCurrentContext();
	CGContextSetShadowWithColor(c, CGSizeMake(0.0f, -1.0f), 0.0f, [[UIColor tableSeparatorLightColor] CGColor]);
	CGRect line = [self bounds];
	line.origin.x = 15.0f;
	line.size.width -= 30.0f;
	line.origin.y = line.size.height - 2.0f;
	line.size.height = 1.0f;
	UIRectFill(line);
	[[UIColor colorWithRed:0.3f green:0.34f blue:0.42f alpha:1.0f] setFill];
	CGContextSetShadowWithColor(c, CGSizeMake(0.0f, -1.0f), 0.0f, [[UIColor whiteColor] CGColor]);
	[[activator localizedStringForKey:@"CURRENTLY_ASSIGNED_TO" value:@"Currently assigned to:"] drawAtPoint:CGPointMake(20.0f, 9.0f) withFont:[UIFont boldSystemFontOfSize:17.0f]];
	if ([_listenerName length]) {
		UIImage *image = [activator smallIconForListenerName:_listenerName];
		CGFloat x;
		if (image) {
			[image drawAtPoint:CGPointMake(20.0f, 35.0f)];
			x = 30.0f + [image size].width;
		} else {
			x = 30.0f;
		}
		[[UIColor blackColor] setFill];
		[[activator localizedTitleForListenerName:_listenerName] drawAtPoint:CGPointMake(x, 39.0f) withFont:[UIFont boldSystemFontOfSize:19.0f]];
	} else {
		[[activator localizedStringForKey:@"UNASSIGNED" value:@"(unassigned)"] drawAtPoint:CGPointMake(30.0f, 40.0f) withFont:[UIFont boldSystemFontOfSize:17.0f]];
	}
}

@end

@interface ActivatorEventViewController : ActivatorTableViewController {
@private
	NSArray *_modes;
	NSString *_eventName;
	NSMutableDictionary *_listeners;
	NSArray *_groups;
	ActivatorEventViewHeader *_headerView;
}
@end

@implementation ActivatorEventViewController

- (void)updateHeader
{
	[_headerView setListenerName:[activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:[_modes objectAtIndex:0]]]];
	[[self tableView] setTableHeaderView:_headerView];
}

- (id)initForContentSize:(CGSize)contentSize withModes:(NSArray *)modes eventName:(NSString *)eventName
{
	if ((self = [super initForContentSize:contentSize])) {
		NSMutableArray *availableModes = [NSMutableArray array];
		for (NSString *mode in modes)
			if ([activator eventWithName:eventName isCompatibleWithMode:mode])
				[availableModes addObject:mode];
		_modes = [availableModes copy];
		_listeners = [[activator _cachedAndSortedListeners] mutableCopy];
		for (NSString *key in [_listeners allKeys]) {
			NSArray *group = [_listeners objectForKey:key];
			NSMutableArray *mutableGroup = [NSMutableArray array];
			BOOL hasItems = NO;
			for (NSString *listenerName in group)
				for (NSString *mode in _modes)
					if ([activator listenerWithName:listenerName isCompatibleWithMode:mode]) {
						[mutableGroup addObject:listenerName];
						hasItems = YES;
						break;
					}
			if (hasItems)
				[_listeners setObject:mutableGroup forKey:key];
			else
				[_listeners removeObjectForKey:key];
		}
		_groups = [[[_listeners allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
		_eventName = [eventName copy];
		CGRect headerFrame;
		headerFrame.origin.x = 0.0f;
		headerFrame.origin.y = 0.0f;
		headerFrame.size.width = contentSize.width;
		headerFrame.size.height = 76.0f;
		_headerView = [[ActivatorEventViewHeader alloc] initWithFrame:headerFrame];
		[self updateHeader];
	}
	return self;
}

- (void)dealloc
{
	[_headerView release];
	[_groups release];
	[_listeners release];
	[_eventName release];
	[_modes release];
	[super dealloc];
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	NSString *title = [activator localizedStringForKey:@"CANT_DEACTIVATE_REMAINING" value:@"Can't deactivate\nremaining event"];
	NSString *message = [NSString stringWithFormat:[activator localizedStringForKey:@"AT_LEAST_ONE_ASSIGNMENT_REQUIRED" value:@"At least one event must be\nassigned to %@"], [activator localizedTitleForListenerName:listenerName]];
	NSString *cancelButtonTitle = [activator localizedStringForKey:@"ALERT_OK" value:@"OK"];
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
	[av show];
	[av release];
}

- (BOOL)allowedToUnassignEventsFromListener:(NSString *)listenerName
{
	if (![activator listenerWithNameRequiresAssignment:listenerName])
		return YES;
	NSInteger assignedCount = [[activator eventsAssignedToListenerWithName:listenerName] count];
	for (NSString *mode in _modes)
		if ([[activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]] isEqual:listenerName])
			assignedCount--;
	return assignedCount > 0;
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_listeners objectForKey:[_groups objectAtIndex:index]];
}

- (NSString *)listenerNameForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_groups count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [_groups objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [[self groupAtIndex:section] count];
}

- (NSInteger)countOfModesAssignedToListener:(NSString *)name
{
	NSInteger result = 0;
	for (NSString *mode in _modes) {
		NSString *assignedName = [activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
		result += [assignedName isEqual:name];
	}
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	[[cell textLabel] setText:[activator localizedTitleForListenerName:listenerName]];
	UITableViewCellAccessoryType accessory = 
		[self countOfModesAssignedToListener:listenerName] ?
		UITableViewCellAccessoryCheckmark :
		UITableViewCellAccessoryNone;
	[[cell detailTextLabel] setText:[activator localizedDescriptionForListenerName:listenerName]];
	[[cell imageView] setImage:[activator smallIconForListenerName:listenerName]];
	[cell setAccessoryType:accessory];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	NSUInteger compatibleModeCount = 0;
	for (NSString *mode in _modes)
		if ([activator listenerWithName:listenerName isCompatibleWithMode:mode])
			compatibleModeCount++;
	BOOL allAssigned = [self countOfModesAssignedToListener:listenerName] >= compatibleModeCount;
	if (allAssigned) {
		if (![self allowedToUnassignEventsFromListener:listenerName]) {
			[self showLastEventMessageForListener:listenerName];
			return;
		}
		[cell setAccessoryType:UITableViewCellAccessoryNone];
		for (NSString *mode in _modes)
			[activator unassignEvent:[LAEvent eventWithName:_eventName mode:mode]];
	} else {
		for (NSString *mode in _modes) {
			NSString *otherListener = [activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
			if (otherListener && ![otherListener isEqual:listenerName]) {
				if (![self allowedToUnassignEventsFromListener:otherListener]) {
					[self showLastEventMessageForListener:otherListener];
					return;
				}
			}
		}
		for (UITableViewCell *otherCell in [tableView visibleCells])
			[otherCell setAccessoryType:UITableViewCellAccessoryNone];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
		for (NSString *mode in _modes) {
			LAEvent *event = [LAEvent eventWithName:_eventName mode:mode];
			if ([activator listenerWithName:listenerName isCompatibleWithMode:mode])
				[activator assignEvent:event toListenerWithName:listenerName];
			else
				[activator unassignEvent:event];
		}
	}
	[self updateHeader];
}

- (NSString *)navigationTitle
{
	return [activator localizedTitleForEventName:_eventName];
}

@end

@interface ActivatorModeViewController : ActivatorTableViewController {
@private
	NSString *_eventMode;
	NSMutableDictionary *_events;
	NSArray *_groups;
}
@end

NSInteger CompareEventNamesCallback(id a, id b, void *context)
{
	return [[activator localizedTitleForEventName:a] localizedCaseInsensitiveCompare:[activator localizedTitleForEventName:b]];
}

@implementation ActivatorModeViewController

- (id)initForContentSize:(CGSize)contentSize withMode:(NSString *)mode
{
	if ((self = [super initForContentSize:contentSize])) {
		_eventMode = [mode copy];
		BOOL showHidden = [[[NSDictionary dictionaryWithContentsOfFile:[activator settingsFilePath]] objectForKey:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
		for (NSString *eventName in [activator availableEventNames]) {
			if ([activator eventWithName:eventName isCompatibleWithMode:mode]) {
				if (!([activator eventWithNameIsHidden:eventName] || showHidden)) {
					NSString *key = [activator localizedGroupForEventName:eventName] ?: @"";
					NSMutableArray *groupList = [_events objectForKey:key];
					if (!groupList) {
						groupList = [NSMutableArray array];
						[_events setObject:groupList forKey:key];
					}
					[groupList addObject:eventName];
				}
			}
		}
		NSArray *groupNames = [_events allKeys];
		for (NSString *key in groupNames)
			[[_events objectForKey:key] sortUsingFunction:CompareEventNamesCallback context:nil];
		_groups = [[groupNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
	}
	return self;
}

- (void)dealloc
{
	[_groups release];
	[_events release];
	[_eventMode release];
	[super dealloc];
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_events objectForKey:[_groups objectAtIndex:index]];
}

- (NSString *)eventNameForIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_groups count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [_groups objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [[self groupAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSInteger row = [indexPath row];
	NSString *eventName = [self eventNameForIndexPath:indexPath];
	CGFloat alpha = [activator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	UILabel *label = [cell textLabel];
	[label setText:[activator localizedTitleForEventName:eventName]];
	[label setAlpha:alpha];
	UILabel *detailLabel = [cell detailTextLabel];
	[detailLabel setText:[activator localizedDescriptionForEventName:eventName]];
	[detailLabel setAlpha:alpha];
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	NSArray *modes = _eventMode ? [NSArray arrayWithObject:_eventMode] : [activator availableEventModes];
	PSViewController *vc = [[ActivatorEventViewController alloc] initForContentSize:[self contentSize] withModes:modes eventName:[self eventNameForIndexPath:indexPath]];
	[self pushController:vc];
	[vc release];
}

- (NSString *)navigationTitle
{
	return [activator localizedTitleForEventMode:_eventMode];
}

@end

@interface ActivatorSettingsController : ActivatorTableViewController {
@private
	NSString *_title;
	LAListenerSettingsViewController *_viewController;
	CGSize _size;
}
@end

@implementation ActivatorSettingsController

- (void)dealloc
{
	[_viewController release];
	[_title release];
	[super dealloc];
}

- (void)viewWillBecomeVisible:(void *)source
{
	// Load LAListenerSettingsViewController if activatorListener is set in the specifier
	[_viewController release];
	_viewController = nil;
	[_title release];
	_title = nil;
	if (source) {
		PSSpecifier *specifier = (PSSpecifier *)source;
		NSString *listenerName = [specifier propertyForKey:@"activatorListener"];
		if ([listenerName length]) {
			NSLog(@"libactivator: Configuring %@", listenerName);
			_viewController = [[LAListenerSettingsViewController alloc] init];
			[_viewController setListenerName:listenerName];
			_title = [[specifier propertyForKey:@"activatorTitle"]?:[specifier name] copy];
		}
	}
	[super viewWillBecomeVisible:source];
}

- (UIView *)view
{
	// Swap out for view controller if set
	UIView *view = [super view];
	if (_viewController) {
		UIView *replacement = [_viewController view];
		[replacement setFrame:[view frame]];
		view = replacement;
	}
	return view;
}

- (NSString *)navigationTitle
{
	if ([_title length])
		return _title;
	else
		return [activator localizedStringForKey:@"ACTIVATOR" value:@"Activator"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return 1;
		case 1:
			return [[activator availableEventModes] count];
		default:
			return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	switch (section) {
		case 1:
			return [activator localizedStringForKey:@"LOCALIZATION_ABOUT" value:@""];
		case 2:
			return @"\u00A9 2009-2010 Ryan Petrich";
		default:
			return nil;
	}
}

- (NSString *)eventModeForIndexPath:(NSIndexPath *)indexPath
{
	switch ([indexPath section]) {
		case 1:
			return [[activator availableEventModes] objectAtIndex:[indexPath row]];
		default:
			return nil;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *eventMode = [self eventModeForIndexPath:indexPath];
	[[cell textLabel] setText:[activator localizedTitleForEventMode:eventMode]];
	[[cell detailTextLabel] setText:[activator localizedDescriptionForEventMode:eventMode]];
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	PSViewController *vc = [[ActivatorModeViewController alloc] initForContentSize:[self contentSize] withMode:[self eventModeForIndexPath:indexPath]];
	[self pushController:vc];
	[vc release];
}

@end
