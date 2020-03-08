//
//  TOSegmentedControl.m
//
//  Copyright 2019 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//#import "TOSegmentedControl.h"
//#import "TOSegmentedControlSegment.h"

// ----------------------------------------------------------------
// Static Members

// A cache to hold images generated for this view that may be shared.
var _imageTable:NSMapTable! = nil

// Statically referenced key names for the images stored in the map table.
let kTOSegmentedControlArrowImage:String! = "arrowIcon"
let kTOSegmentedControlSeparatorImage:String! = "separatorImage"

// When tapped the amount the focused elements will shrink / fade
let kTOSegmentedControlSelectedTextAlpha:CGFloat = 0.3
let kTOSegmentedControlDisabledAlpha:CGFloat = 0.4
let kTOSegmentedControlSelectedScale:CGFloat = 0.95
let kTOSegmentedControlDirectionArrowAlpha:CGFloat = 0.4
let kTOSegmentedControlDirectionArrowMargin:CGFloat = 2.0

// ----------------------------------------------------------------
// Private Members


class TOSegmentedControl {

    // MARK: - Class Init -

    private var _segments:NSMutableArray!
    private var segments:NSMutableArray! {
        get { return _segments }
        set { _segments = newValue }
    }
    private var isDraggingThumbView:Bool
    private var didDragOffOriginalSegment:Bool
    private var focusedIndex:Int
    private var _trackView:UIView!
    private var trackView:UIView! {
        get { return _trackView }
        set { _trackView = newValue }
    }
    private var thumbView:UIView!
    private var separatorViews:NSMutableArray!
    private(set) var imageTable:NSMapTable!
    private(set) var arrowImage:UIImage!
    private(set) var separatorImage:UIImage!
    private(set) var segmentWidth:CGFloat

    init(items:[AnyObject]!) {
        if (self = super.init(frame:CGRectMake(0.0, 0.0, 300.0, 32.0)) != nil) {
            self.commonInit()
            self.items = self.sanitizedItemArrayWithItems(items)
        }

        return self
    }

    init(coder:NSCoder!) {
        if (self = super.init(coder:coder) != nil) {
            self.commonInit()
        }

        return self
    }

    init(frame:CGRect) {
        if (self = super.init(frame:frame) != nil) {
            self.commonInit()
        }

        return self
    }

    init() {
        if (self = super.init(frame:CGRectMake(0.0, 0.0, 300.0, 32.0)) != nil) {
            self.commonInit()
        }

        return self
    }

    func commonInit() {
        // Create content view
        self.trackView = UIView(frame:self.bounds)
        self.trackView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight
        self.trackView.layer.masksToBounds = true
        self.trackView.userInteractionEnabled = false
        #ifdef __IPHONE_13_0
        if #available(iOS 13.0, *) { self.trackView.layer.cornerCurve = kCACornerCurveContinuous }
        #endif
        self.addSubview(self.trackView)

        // Create thumb view
        self.thumbView = UIView(frame:CGRectMake(2.0, 2.0, 100.0, 28.0))
        self.thumbView.layer.shadowColor = UIColor.blackColor().CGColor
        #ifdef __IPHONE_13_0
        if #available(iOS 13.0, *) { self.thumbView.layer.cornerCurve = kCACornerCurveContinuous }
        #endif
        self.trackView.addSubview(self.thumbView)

        // Create list for managing each item
        self.segments = NSMutableArray.array()

        // Create containers for views
        self.separatorViews = NSMutableArray.array()

        // Set default resettable values
        self.backgroundColor() = nil
        self.thumbColor() = nil
        self.separatorColor = nil
        self.itemColor = nil
        self.selectedItemColor = nil
        self.textFont = nil
        self.selectedTextFont = nil

        // Set default values
        self.selectedSegmentIndex = -1
        self.cornerRadius() = 8.0
        self.thumbInset = 2.0
        self.thumbShadowRadius() = 3.0
        self.thumbShadowOffset() = 2.0
        self.thumbShadowOpacity() = 0.13

        // Configure view interaction
        // When the user taps down in the view
        self.addTarget(self,
                 action:Selector("didTapDown:withEvent:"),
       forControlEvents:UIControlEventTouchDown)

        // When the user drags, either inside or out of the view
        self.addTarget(self,
                 action:Selector("didDragTap:withEvent:"),
       forControlEvents:UIControlEventTouchDragInside|UIControlEventTouchDragOutside)

        // When the user's finger leaves the bounds of the view
        self.addTarget(self,
                 action:Selector("didExitTapBounds:withEvent:"),
       forControlEvents:UIControlEventTouchDragExit)

        // When the user's finger re-enters the bounds
        self.addTarget(self,
                 action:Selector("didEnterTapBounds:withEvent:"),
       forControlEvents:UIControlEventTouchDragEnter)

        // When the user taps up, either inside or out
        self.addTarget(self,
                 action:Selector("didEndTap:withEvent:"),
       forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside)
    }

    // MARK: - Item Management -

    func sanitizedItemArrayWithItems(items:[AnyObject]!) -> NSMutableArray! {
        // Filter the items to extract only strings and images
        let sanitizedItems:NSMutableArray! = NSMutableArray.array()
        for item:AnyObject! in items {  
            if !(item is UIImage) && !(item is NSString) {
                continue
            }
            sanitizedItems.addObject(item)
         }

        return sanitizedItems
    }

    func updateSeparatorViewCount() {
        let numberOfSeparators:Int = (self.items.count - 1)

        // Add as many separators as needed
        while  self.separatorViews.count < numberOfSeparators {
            let separator:UIImageView! = UIImageView(image:self.separatorImage)
            separator.tintColor = self.separatorColor
            self.trackView.insertSubview(separator, atIndex:0)
            self.separatorViews.addObject(separator)
        }

        // Substract as many separators as needed
        while  self.separatorViews.count > numberOfSeparators {
            let separator:UIView! = self.separatorViews.lastObject
            self.separatorViews.removeLastObject()
            separator.removeFromSuperview()
        }
    }

    // MARK: - Public Item Access -

    func imageForSegmentAtIndex(index:Int) -> UIImage? {
        if index < 0 || index >= self.segments.count { return nil }
        return self.objectForSegmentAtIndex(index, class:UIImage.self)
    }

    func titleForSegmentAtIndex(index:Int) -> String? {
        return self.objectForSegmentAtIndex(index, class:String.self)
    }

    func objectForSegmentAtIndex(index:Int, class:AnyClass) -> AnyObject? {
        // Make sure the index provided is valid
        if index < 0 || index >= self.items.count { return nil }

        // Return the item only if it is an image
        let item:AnyObject! = self.items[index]
        if (item is class) { return item }

        // Return nil if a label or anything else
        return nil
    }

    // MARK: Add New Items

    func addNewSegmentWithImage(image:UIImage!) {
        self.addNewSegmentWithImage(image, reversible:false)
    }

    func addNewSegmentWithImage(image:UIImage!, reversible:Bool) {
        self.addNewSegmentWithObject(image, reversible:reversible)
    }

    func addNewSegmentWithTitle(title:String!) {
        self.addNewSegmentWithTitle(title, reversible:false)
    }

    func addNewSegmentWithTitle(title:String!, reversible:Bool) {
        self.addNewSegmentWithObject(title, reversible:reversible)
    }

    func addNewSegmentWithObject(object:AnyObject!, reversible:Bool) {
        self.insertSegmentWithObject(object, reversible:reversible, atIndex:self.items.count)
    }

    // MARK: Inserting New Items

    func insertSegmentWithTitle(title:String!, atIndex index:Int) {
        self.insertSegmentWithTitle(title, reversible:false, atIndex:index)
    }

    func insertSegmentWithTitle(title:String!, reversible:Bool, atIndex index:Int) {
        self.insertSegmentWithObject(title, reversible:reversible, atIndex:index)
    }

    func insertSegmentWithImage(image:UIImage!, atIndex index:Int) {
        self.insertSegmentWithImage(image, reversible:false, atIndex:index)
    }

    func insertSegmentWithImage(image:UIImage!, reversible:Bool, atIndex index:Int) {
        self.insertSegmentWithObject(image, reversible:reversible, atIndex:index)
    }

    func insertSegmentWithObject(object:AnyObject!, reversible:Bool, atIndex index:Int) {
        // Add item to master list
        let items:NSMutableArray! = self.items.mutableCopy()
        items.insertObject(object, atIndex:index)
        _items = [AnyObject].arrayWithArray(items)

        // Add new item object to internal list
        let segment:TOSegmentedControlSegment! = TOSegmentedControlSegment(object:object,
                                                                 forSegmentedControl:self)
        segment.isReversible = reversible
        self.segments.insertObject(segment, atIndex:index)

       // Update number of separators
       self.updateSeparatorViewCount()

       // Perform new layout update
       self.setNeedsLayout()
    }

    // MARK: Replacing Items

    func setImage(image:UIImage!, forSegmentAtIndex index:Int) {
        self.setImage(image, reversible:false, forSegmentAtIndex:index)
    }

    func setImage(image:UIImage!, reversible:Bool, forSegmentAtIndex index:Int) {
        self.setObject(image, reversible:reversible, forSegmentAtIndex:index)
    }

    func setTitle(title:String!, forSegmentAtIndex index:Int) {
        self.setTitle(title, reversible:false, forSegmentAtIndex:index)
    }

    func setTitle(title:String!, reversible:Bool, forSegmentAtIndex index:Int) {
        self.setObject(title, reversible:reversible, forSegmentAtIndex:index)
    }

    func setObject(object:AnyObject!, reversible:Bool, forSegmentAtIndex index:Int) {
        NSAssert(object.isKindOfClass(String.self) || object.isKindOfClass(UIImage.self),
                    "TOSegmentedControl: Only images and strings are supported.")

        // Make sure we don't go out of bounds
        if index < 0 || index >= self.items.count { return }

        // Remove the item from the item list and insert the new one
        let items:NSMutableArray! = self.items.mutableCopy()
        items.removeObjectAtIndex(index)
        items.insertObject(object, atIndex:index)
        _items = [AnyObject].arrayWithArray(items)

        // Update the item object at that point for the new item
        let segment:TOSegmentedControlSegment! = self.segments[index]
        if object.isKindOfClass(String.self) { segment.title = object }
        if object.isKindOfClass(UIImage.self) { segment.image = object }
        segment.isReversible = reversible

        // Re-layout the views
        self.setNeedsLayout()
    }

    // MARK: Deleting Items

    func removeLastSegment() {
        self.removeSegmentAtIndex(self.items.count - 1)
    }

    func removeSegmentAtIndex(index:Int) {
        if index < 0 || index >= self.items.count { return }

        // Remove from the item list
        let items:NSMutableArray! = self.items.mutableCopy
        items.removeObjectAtIndex(index)
        _items = items

        // Remove item object
        self.segments.removeObjectAtIndex(index)

        // Update number of separators
        self.updateSeparatorViewCount()
    }

    func removeAllSegments() {
        // Remove all item objects
        self.segments = NSMutableArray.array()

        // Remove all separators
        for separator:UIView! in self.separatorViews {  
            separator.removeFromSuperview()
         }
        self.separatorViews.removeAllObjects()

        // Delete the items array
        self.items = nil
    }

    // MARK: Enabled/Disabled

    func setEnabled(enabled:Bool, forSegmentAtIndex index:Int) {
        if index < 0 || index >= self.segments.count { return }
        self.segments[index].isDisabled = !enabled
        self.setNeedsLayout()

        // If we disabled the selected index, choose another one
        if self.selectedSegmentIndex >= 0 && !self.segments[self.selectedSegmentIndex].isDisabled {
            return
        }

        // Loop ahead of the selected segment index to find the next enabled one
        for var i:Int=self.selectedSegmentIndex ; i < self.segments.count ; i++ {  
            if self.segments[i].isDisabled { continue }
            self.selectedSegmentIndex = i
            return
         }

        // If that failed, loop forward to find an enabled one before it
        for var i:Int=self.selectedSegmentIndex ; i >= 0 ; i-- {  
            if self.segments[i].isDisabled { continue }
            self.selectedSegmentIndex = i
            return
         }

        // Nothing is enabled, default back to deselecting everything
        self.selectedSegmentIndex = -1
    }

    func isEnabledForSegmentAtIndex(index:Int) -> Bool {
        if index < 0 || index >= self.segments.count { return false }
        return !self.segments[index].isDisabled
    }

    // MARK: - Reversible Management -

    // Accessors for setting when a segment is reversible.

    func setReversible(reversible:Bool, forSegmentAtIndex index:Int) {
        if index < 0 || index >= self.segments.count { return }
        self.segments[index].isReversible = reversible
    }

    func isReversibleForSegmentAtIndex(index:Int) -> Bool {
        if index < 0 || index >= self.segments.count { return false }
        return !self.segments[index].isReversible
    }

    // Accessors for toggling whether a reversible segment is currently reversed.
    func setReversed(reversed:Bool, forSegmentAtIndex index:Int) {
        if index < 0 || index >= self.segments.count { return }
        self.segments[index].isReversed = reversed
    }

    func isReversedForSegmentAtIndex(index:Int) -> Bool {
        if index < 0 || index >= self.segments.count { return false }
        return !self.segments[index].isReversed
    }

    // MARK: - View Layout -

    func layoutThumbView() {
        // Hide the thumb view if no segments are selected
        if self.selectedSegmentIndex < 0 || !self.enabled {
            self.thumbView.hidden = true
            return
        }

        // Lay-out the thumb view
        let frame:CGRect = self.frameForSegmentAtIndex(self.selectedSegmentIndex)
        self.thumbView.frame = frame
        self.thumbView.hidden = false

        // Match the shadow path to the new size of the thumb view
        let oldShadowPath:CGPathRef = self.thumbView.layer.shadowPath
        let shadowPath:UIBezierPath! = UIBezierPath.bezierPathWithRoundedRect(CGRectMake(CGPointZero.x, CGPointZero.y, frame.size.width, frame.size.height),
                                                              cornerRadius:self.cornerRadius() - self.thumbInset)

        // If the segmented control is animating its shape, to prevent the
        // shadow from visibly snapping, perform a resize animation on it
        let boundsAnimation:CABasicAnimation! = self.layer.animationForKey("bounds.size")
        if oldShadowPath != nil && boundsAnimation {
            let shadowAnimation:CABasicAnimation! = CABasicAnimation.animationWithKeyPath("shadowPath")
            shadowAnimation.fromValue = (oldShadowPath as! id)
            shadowAnimation.toValue = (shadowPath.CGPath as! id)
            shadowAnimation.duration = boundsAnimation.duration
            shadowAnimation.timingFunction = boundsAnimation.timingFunction
            self.thumbView.layer.addAnimation(shadowAnimation, forKey:"shadowPath")
        }
        self.thumbView.layer.shadowPath = shadowPath.CGPath
    }

    func layoutItemViews() {
        // Lay out the item views
        let i:Int = 0
        for item:TOSegmentedControlSegment! in self.segments {  
            let itemView:UIView! = item.itemView
            itemView.sizeToFit()
            self.trackView.addSubview(itemView)

            // Get the container frame that the item will be aligned with
            let thumbFrame:CGRect = self.frameForSegmentAtIndex(i)

            // Work out the appropriate size of the item
            var itemFrame:CGRect = itemView.frame

            // Cap its size to be within the segmented frame
            itemFrame.size.height = min(thumbFrame.size.height, itemFrame.size.height)
            itemFrame.size.width = min(thumbFrame.size.width, itemFrame.size.width)

            // If the item is reversible, make sure there is also room to show the arrow
            let arrowSpacing:CGFloat = (self.arrowImage.size.width + kTOSegmentedControlDirectionArrowMargin) * 2.0
            if item.isReversible && (itemFrame.size.width + arrowSpacing) > thumbFrame.size.width {
                itemFrame.size.width -= arrowSpacing
            }

            // Center the item in the container
            itemFrame.origin.x = CGRectGetMidX(thumbFrame) - (itemFrame.size.width * 0.5)
            itemFrame.origin.y = CGRectGetMidY(thumbFrame) - (itemFrame.size.height * 0.5)

            // Set the item frame
            itemView.frame = CGRectIntegral(itemFrame)

            // Make sure they are all unselected
            self.setItemAtIndex(i, selected:false)

            // If the item is disabled, make it faded
            if !self.enabled || item.isDisabled {
                itemView.alpha = kTOSegmentedControlDisabledAlpha
            }

            i++
         }

        // Exit out if there is nothing selected
        if self.selectedSegmentIndex < 0 { return }

        // Set the selected state for the current selected index
        self.setItemAtIndex(self.selectedSegmentIndex, selected:true)
    }

    func layoutSeparatorViews() {
        let size:CGSize = self.trackView.frame.size
        let segmentWidth:CGFloat = self.segmentWidth
        let xOffset:CGFloat = (_thumbInset + segmentWidth) - 1.0
        let i:Int = 0
        for separatorView:UIView! in self.separatorViews {  
           var frame:CGRect = separatorView.frame
           frame.size.width = 1.0
           frame.size.height = (size.height - (self.cornerRadius()) * 2.0) + 2.0
           frame.origin.x = xOffset + (segmentWidth * i)
           frame.origin.y = (size.height - frame.size.height) * 0.5
           separatorView.frame = CGRectIntegral(frame)
           i++
         }

       // Update the alpha of the separator views
       self.refreshSeparatorViewsForSelectedIndex(self.selectedSegmentIndex)
    }

    func layoutSubviews() {
        super.layoutSubviews()

        // Lay-out the thumb view
        self.layoutThumbView()

        // Lay-out the item views
        self.layoutItemViews()

        // Lay-out the separator views
        self.layoutSeparatorViews()
    }

    func segmentWidth() -> CGFloat {
        return floorf((self.bounds.size.width - (_thumbInset * 2.0)) / self.numberOfSegments())
    }

    func frameForSegmentAtIndex(index:Int) -> CGRect {
        let size:CGSize = self.trackView.frame.size

        var frame:CGRect = CGRectZero
        frame.origin.x = _thumbInset + (self.segmentWidth * index) + ((_thumbInset * 2.0) * index)
        frame.origin.y = _thumbInset
        frame.size.width = self.segmentWidth
        frame.size.height = size.height - (_thumbInset * 2.0)

        // Cap the position of the frame so it won't overshoot
        frame.origin.x = max(_thumbInset, frame.origin.x)
        frame.origin.x = min(size.width - (self.segmentWidth + _thumbInset), frame.origin.x)

        return CGRectIntegral(frame)
    }

    func frameForImageArrowViewWithItemFrame(itemFrame:CGRect) -> CGRect {
        var frame:CGRect = CGRectZero
        frame.size = self.arrowImage.size
        frame.origin.x = CGRectGetMaxX(itemFrame) + kTOSegmentedControlDirectionArrowMargin
        frame.origin.y = ceilf(CGRectGetMidY(itemFrame) - (frame.size.height * 0.5))
        return frame
    }

    func segmentIndexForPoint(point:CGPoint) -> Int {
        let segmentWidth:CGFloat = floorf(self.frame.size.width / self.numberOfSegments())
        var segment:Int = floorf(point.x / segmentWidth)
        segment = max(segment, 0)
        segment = min(segment, self.numberOfSegments()-1)
        return segment
    }

    func setThumbViewShrunken(shrunken:Bool) {
        let scale:CGFloat = shrunken ? kTOSegmentedControlSelectedScale : 1.0
        self.thumbView.transform = CGAffineTransformScale(CGAffineTransformIdentity,
                                                          scale, scale)
    }

    func setItemViewAtIndex(segmentIndex:Int, shrunken:Bool) {
        NSAssert(segmentIndex >= 0 && segmentIndex < self.items.count,
                 "TOSegmentedControl: Array should not be out of bounds")

        let segment:TOSegmentedControlSegment! = self.segments[segmentIndex]
        let itemView:UIView! = segment.itemView
        let itemFrame:CGRect = itemView.frame
        let itemViewCenter:CGPoint = itemView.center

        if shrunken == false {
            itemView.transform = CGAffineTransformIdentity
        }
        else {
            let scale:CGFloat = kTOSegmentedControlSelectedScale
            itemView.transform = CGAffineTransformScale(CGAffineTransformIdentity,
                                                              scale, scale)
        }

        // If we have a reversible image view, manipulate its transformation
        // to match the position and scale of the item view
        let arrowView:UIView! = segment.arrowView
        if arrowView == nil { return }

        if !shrunken {
            arrowView.transform = CGAffineTransformIdentity
            return
        }

        let scale:CGFloat = kTOSegmentedControlSelectedScale
        let arrowFrame:CGRect = self.frameForImageArrowViewWithItemFrame(itemFrame)

        // Work out the delta between the middle of the item view,
        // and the middle of the image view
        var offset:CGPoint = CGPointZero
        offset.x = (CGRectGetMidX(arrowFrame) - itemViewCenter.x)

        // Create a transformation matrix that applies the scale to the arrow,
        // with the transformation origin being the middle of the item view
        var transform:CGAffineTransform = arrowView.transform
        transform = CGAffineTransformTranslate(transform, -offset.x, -offset.y)
        transform = CGAffineTransformScale(transform, scale, scale)
        transform = CGAffineTransformTranslate(transform, offset.x, offset.y)
        arrowView.transform = transform
    }

    func setItemViewAtIndex(segmentIndex:Int, reversed:Bool) {
        NSAssert(segmentIndex >= 0 && segmentIndex < self.items.count,
                 "TOSegmentedControl: Array should not be out of bounds")

        let segment:TOSegmentedControlSegment! = self.segments[segmentIndex]
        segment.arrowImageReversed = reversed
    }

    func setItemAtIndex(index:Int, selected:Bool) {
        NSAssert(index >= 0 && index < self.segments.count,
                 "TOSegmentedControl: Array should not be out of bounds")

        // Tell the segment to select itself in order to show the reversible arrow
        let segment:TOSegmentedControlSegment! = self.segments[index]

        // Update the alpha of the reversible arrow
        segment.arrowView!.alpha = selected ? kTOSegmentedControlDirectionArrowAlpha : 0.0

        // The rest of this code deals with swapping the font
        // of the label. Cancel out if we're an image.
        let label:UILabel! = segment.label
        if label == nil { return }

        // Set the font
        let font:UIFont! = selected ? self.selectedTextFont : self.textFont
        label.font = font

        // Set the text color
        label.textColor = selected ? self.selectedItemColor : self.itemColor

        // Re-apply the arrow image view to the translated frame
        segment.arrowView!.frame = self.frameForImageArrowViewWithItemFrame(label.frame)

        // Ensure the arrow view is set to the right orientation
        segment.arrowImageReversed = segment.isReversed
    }

    func setItemAtIndex(index:Int, faded:Bool) {
        NSAssert(index >= 0 && index < self.segments.count,
                 "Array should not be out of bounds")
        let itemView:UIView! = self.segments[index].itemView
        itemView.alpha = faded ? kTOSegmentedControlSelectedTextAlpha : 1.0
    }

    func refreshSeparatorViewsForSelectedIndex(index:Int) {
        // Hide the separators on either side of the selected segment
        let i:Int = 0
        for separatorView:UIView! in self.separatorViews {  
            // if the view is disabled, the thumb view will be hidden
            if !self.enabled {
                separatorView.alpha = 1.0
                continue
            }

            separatorView.alpha = (i == index || i == (index - 1)) ? 0.0 : 1.0
            i++
         }
    }

    // MARK: - Touch Interaction -

    func didTapDown(control:UIControl!, withEvent event:UIEvent!) {
        // Exit out if the control is disabled
        if !self.enabled { return }

        // Determine which segment the user tapped
        let tapPoint:CGPoint = event.allTouches.anyObject.locationInView(self)
        let tappedIndex:Int = self.segmentIndexForPoint(tapPoint)

        // If the control or item is disabled, pass
        if self.segments[tappedIndex].isDisabled {
            return
        }

        // Work out if we tapped on the thumb view, or on an un-selected segment
        self.isDraggingThumbView = (tappedIndex == self.selectedSegmentIndex)

        // Track if we drag off this segment
        self.didDragOffOriginalSegment = false

        // Track the currently selected item as the focused one
        self.focusedIndex = tappedIndex

        // Work out which animation effects to apply
        if !self.isDraggingThumbView {
            UIView.animateWithDuration(0.35, animations:{ 
                self.setItemAtIndex(tappedIndex, faded:true)
            })
            return
        }

        let animationBlock:AnyObject! = { 
            self.thumbViewShrunken = true
            self.setItemViewAtIndex(self.selectedSegmentIndex, shrunken:true)
        }

        // Animate the transition
        UIView.animateWithDuration(0.3,
                              delay:0.0,
             usingSpringWithDamping:1.0,
              initialSpringVelocity:0.1,
                            options:UIViewAnimationOptionBeginFromCurrentState,
                         animations:animationBlock,
                         completion:nil)
    }

    func didDragTap(control:UIControl!, withEvent event:UIEvent!) {
        // Exit out if the control is disabled
        if !self.enabled { return }

        let tapPoint:CGPoint = event.allTouches.anyObject.locationInView(self)
        let tappedIndex:Int = self.segmentIndexForPoint(tapPoint)

        if tappedIndex == self.focusedIndex { return }

        // If the control or item is disabled, pass
        if self.segments[tappedIndex].isDisabled {
            return
        }

        // Track that we dragged off the first segments
        self.didDragOffOriginalSegment = true

        // Handle transitioning when not dragging the thumb view
        if !self.isDraggingThumbView {
            // If we dragged out of the bounds, disregard
            if self.focusedIndex < 0 { return }

            let animationBlock:AnyObject! = { 
                // Deselect the current item
                self.setItemAtIndex(self.focusedIndex, faded:false)

                // Fade the text if it is NOT the thumb track one
                if tappedIndex != self.selectedSegmentIndex {
                    self.setItemAtIndex(tappedIndex, faded:true)
                }
            }

            // Perform a faster change over animation
            UIView.animateWithDuration(0.3,
                                  delay:0.0,
                                options:UIViewAnimationOptionBeginFromCurrentState,
                             animations:animationBlock,
                             completion:nil)

            // Update the focused item
            self.focusedIndex = tappedIndex
            return
        }

        // Get the new frame of the segment
        let frame:CGRect = self.frameForSegmentAtIndex(tappedIndex)

        // Work out the center point from the frame
        let center:CGPoint = {CGRectGetMidX(frame), CGRectGetMidY(frame)}

        // Create the animation block
        let animationBlock:AnyObject! = { 
            self.thumbView.center = center

            // Deselect the focused item
            self.setItemAtIndex(self.focusedIndex, selected:false)
            self.setItemViewAtIndex(self.focusedIndex, shrunken:false)

            // Select the new one
            self.setItemAtIndex(tappedIndex, selected:true)
            self.setItemViewAtIndex(tappedIndex, shrunken:true)

            // Update the separators
            self.refreshSeparatorViewsForSelectedIndex(tappedIndex)
        }

        // Perform the animation
        UIView.animateWithDuration(0.45,
                              delay:0.0,
             usingSpringWithDamping:1.0,
              initialSpringVelocity:1.0,
                            options:UIViewAnimationOptionBeginFromCurrentState,
                         animations:animationBlock,
                         completion:nil)

        // Update the focused item
        self.focusedIndex = tappedIndex
    }

    func didExitTapBounds(control:UIControl!, withEvent event:UIEvent!) {
        // Exit out if the control is disabled
        if !self.enabled { return }

        // No effects needed when tracking the thumb view
        if self.isDraggingThumbView { return }

        // Un-fade the focused item
        UIView.animateWithDuration(0.45,
                              delay:0.0,
                            options:UIViewAnimationOptionBeginFromCurrentState,
                         animations:{  self.setItemAtIndex(self.focusedIndex, faded:false) },
                         completion:nil)

        // Disable the focused index
        self.focusedIndex = -1
    }

    func didEnterTapBounds(control:UIControl!, withEvent event:UIEvent!) {
        // Exit out if the control is disabled
        if !self.enabled { return }

        // No effects needed when tracking the thumb view
        if self.isDraggingThumbView { return }

        let tapPoint:CGPoint = event.allTouches.anyObject.locationInView(self)
        self.focusedIndex = self.segmentIndexForPoint(tapPoint)

        // Un-fade the focused item
        UIView.animateWithDuration(0.45,
                              delay:0.0,
                            options:UIViewAnimationOptionBeginFromCurrentState,
                         animations:{  self.setItemAtIndex(self.focusedIndex, faded:true) },
                         completion:nil)
    }

    func didEndTap(control:UIControl!, withEvent event:UIEvent!) {
        // Exit out if the control is disabled
        if !self.enabled { return }

        // Work out the final place where we released
        let tapPoint:CGPoint = event.allTouches.anyObject.locationInView(self)
        let tappedIndex:Int = self.segmentIndexForPoint(tapPoint)

        let segment:TOSegmentedControlSegment! = self.segments[tappedIndex]

        // If we WEREN'T dragging the thumb view, work out where we need to move to
        if !self.isDraggingThumbView {
            if segment.isDisabled { return }

            // If we actually changed, update the segmented index and trigger the callbacks
            if self.selectedSegmentIndex != tappedIndex {
                // Set the new selected segment index
                _selectedSegmentIndex = tappedIndex

                // Trigger the notification to all of the delegates
                self.sendIndexChangedEventActions()
            }

            // Create an animation block that will update the position of the
            // thumb view and restore all of the item views
            let animationBlock:AnyObject! = { 
                // Un-fade all of the item views
                for var i:Int=0 ; i < self.segments.count ; i++ {  
                    // De-select everything
                    self.setItemAtIndex(i, faded:false)
                    self.setItemAtIndex(i, selected:false)

                    // Select the currently selected index
                    self.setItemAtIndex(self.selectedSegmentIndex, selected:true)

                    // Move the thumb view
                    self.thumbView.frame = self.frameForSegmentAtIndex(self.selectedSegmentIndex)

                    // Update the separators
                    self.refreshSeparatorViewsForSelectedIndex(self.selectedSegmentIndex)
                 }
            }

            // Commit the animation
            UIView.animateWithDuration(0.45,
                                  delay:0.0,
                 usingSpringWithDamping:1.0,
                  initialSpringVelocity:2.0,
                                options:UIViewAnimationOptionBeginFromCurrentState,
                             animations:animationBlock,
                             completion:nil)

            // Reset the focused index flag
            self.focusedIndex = -1

            return
        }

        // Update the state and alert the delegate
        if self.selectedSegmentIndex != tappedIndex {
            _selectedSegmentIndex = tappedIndex
            self.sendIndexChangedEventActions()
        }
        else if segment.isReversible && !self.didDragOffOriginalSegment {
            // If the item was reversible, and we never changed segments,
            // trigger the reverse alert delegate
            segment.toggleDirection()
            self.sendIndexChangedEventActions()
        }

        // Work out which animation effects to apply
        let animationBlock:AnyObject! = { 
            self.thumbViewShrunken = false
            self.setItemViewAtIndex(self.selectedSegmentIndex, shrunken:false)
            self.setItemViewAtIndex(self.selectedSegmentIndex,
                            reversed:self.selectedSegmentReversed())
        }

        // Animate the transition
        UIView.animateWithDuration(0.3,
                             delay:0.0,
            usingSpringWithDamping:1.0,
             initialSpringVelocity:0.1,
                           options:UIViewAnimationOptionBeginFromCurrentState,
                        animations:animationBlock,
                        completion:nil)

        // Reset the focused index flag
        self.focusedIndex = -1
    }

    func sendIndexChangedEventActions() {
        // Trigger the action event for any targets that were
        self.sendActionsForControlEvents(UIControlEventValueChanged)

        // Trigger the block if it is set
        if self.segmentTappedHandler {
            self.segmentTappedHandler(self.selectedSegmentIndex,
                                      self.selectedSegmentReversed())
        }
    }

    // MARK: - Accessors -

    // -----------------------------------------------
    // Selected Item Index

    func setSelectedSegmentIndex(selectedSegmentIndex:Int) {
        if self.selectedSegmentIndex == selectedSegmentIndex { return }

        // Set the new value
        _selectedSegmentIndex = selectedSegmentIndex

        // Cap the value
        _selectedSegmentIndex = max(selectedSegmentIndex, -1)
        _selectedSegmentIndex = min(selectedSegmentIndex, self.numberOfSegments() - 1)

        // Send the update alert
        if _selectedSegmentIndex >= 0 {
            self.sendIndexChangedEventActions()
        }

        // Trigger a view layout
        self.setNeedsLayout()
    }

    // -----------------------------------------------
    // Selected Item Reversed

    func setSelectedSegmentReversed(selectedSegmentReversed:Bool) {
        if self.selectedSegmentIndex < 0 { return }
        let segment:TOSegmentedControlSegment! = self.segments[self.selectedSegmentIndex]
        if segment.isReversible == false { return }
        segment.isReversed = selectedSegmentReversed
    }

    func selectedSegmentReversed() -> Bool {
        if self.selectedSegmentIndex < 0 { return false }
        let segment:TOSegmentedControlSegment! = self.segments[self.selectedSegmentIndex]
        if segment.isReversible == false { return false }
        return segment.isReversed
    }

    // -----------------------------------------------
    // Items

    func setItems(items:[AnyObject]!) {
        if items == _items { return }

        // Remove all current items
        self.removeAllSegments()

        // Set the new array
        _items = self.sanitizedItemArrayWithItems(items)

        // Create the list of item objects  to track their state
        _segments = TOSegmentedControlSegment.segmentsWithObjects(_items,
                                            forSegmentedControl:self).mutableCopy

        // Update the number of separators
        self.updateSeparatorViewCount()

        // Trigger a layout update
        self.setNeedsLayout()

        // Set the initial selected index
        self.selectedSegmentIndex = (_items.count > 0) ? 0 : -1
    }

    // -----------------------------------------------
    // Corner Radius

    func setCornerRadius(cornerRadius:CGFloat) {
        self.trackView.layer.cornerRadius = cornerRadius
        self.thumbView.layer.cornerRadius = (self.cornerRadius() - _thumbInset) + 1.0
    }

    func cornerRadius() -> CGFloat { return self.trackView.layer.cornerRadius }

    // -----------------------------------------------
    // Thumb Color

    func setThumbColor(thumbColor:UIColor!) {
        self.thumbView.backgroundColor = thumbColor
        if self.thumbView.backgroundColor != nil { return }

        // On iOS 12 and below, simply set the thumb view to be white
        self.thumbView.backgroundColor = UIColor.whiteColor()

        // For iOS 13 and up, create a dynamic provider that will trigger a color change
        #ifdef __IPHONE_13_0
        if #available(iOS 13.0, *) {
            // Create the provider block that will trigger each time the trait collection changes
            let dynamicColorProvider:AnyObject! = { (traitCollection:UITraitCollection!) in 
                // Dark color
                if traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark {
                    return UIColor(red:0.357, green:0.357, blue:0.376, alpha:1.0)
                }

                // Default light color
                return UIColor.whiteColor()
            }

            // Assign the dynamic color to the view
            self.thumbView.backgroundColor = UIColor(dynamicProvider:dynamicColorProvider)
        }
        #endif
    }
    func thumbColor() -> UIColor! { return self.thumbView.backgroundColor }

    // -----------------------------------------------
    // Background Color

    func setBackgroundColor(backgroundColor:UIColor!) {
        super.backgroundColor = UIColor.clearColor()
        _trackView.backgroundColor = backgroundColor

        // Exit out if we don't need to reset to defaults
        if _trackView.backgroundColor != nil { return }

        // Set the default color for iOS 12 and below
        backgroundColor = UIColor(red:0.0, green:0.0, blue:0.08, alpha:0.06666)
        _trackView.backgroundColor = backgroundColor

        // For iOS 13 and up, create a dynamic provider that will trigger on trait changes
        #ifdef __IPHONE_13_0
        if #available(iOS 13.0, *) {

            // Create the provider block that will trigger each time the trait collection changes
            let dynamicColorProvider:AnyObject! = { (traitCollection:UITraitCollection!) in 
                // Dark color
                if traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark {
                    return UIColor(red:0.898, green:0.898, blue:1.0, alpha:0.12)
                }

                // Default light color
                return backgroundColor
            }

            // Assign the dynamic color to the view
            _trackView.backgroundColor = UIColor(dynamicProvider:dynamicColorProvider)
        }
        #endif
    }
    func backgroundColor() -> UIColor! { return self.trackView.backgroundColor }

    // -----------------------------------------------
    // Separator Color

    func setSeparatorColor(separatorColor:UIColor!) {
        _separatorColor = separatorColor
        if _separatorColor == nil {
            // Set the default color for iOS 12 and below
            separatorColor = UIColor(red:0.0, green:0.0, blue:0.08, alpha:0.1)

            // On iOS 13 and up, set up a dynamic provider for dynamic light and dark colors
            #ifdef __IPHONE_13_0
            if #available(iOS 13.0, *) {
                // Create the provider block that will trigger each time the trait collection changes
                let dynamicColorProvider:AnyObject! = { (traitCollection:UITraitCollection!) in 
                    // Dark color
                    if traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark {
                        return UIColor(red:0.918, green:0.918, blue:1.0, alpha:0.16)
                    }

                    // Default light color
                    return separatorColor
                }

                // Assign the dynamic color to the view
                separatorColor = UIColor(dynamicProvider:dynamicColorProvider)
            }
            #endif

            _separatorColor = separatorColor
        }

        for separatorView:UIView! in self.separatorViews {  
            separatorView.tintColor = _separatorColor
         }
    }

    // -----------------------------------------------
    // Item Color

    func setItemColor(itemColor:UIColor!) {
        _itemColor = itemColor
        if _itemColor == nil {
            _itemColor = UIColor.blackColor()

            // Assign the dynamic label color on iOS 13 and up
            #ifdef __IPHONE_13_0
            if #available(iOS 13.0, *) {
                _itemColor = UIColor.labelColor()
            }
            #endif
        }

        // Set each item to the color
        for item:TOSegmentedControlSegment! in self.segments {  
            item.refreshItemView()
         }
    }

    //-------------------------------------------------
    // Selected Item Color

    func setSelectedItemColor(selectedItemColor:UIColor!) {
        _selectedItemColor = selectedItemColor
        if _selectedItemColor == nil {
            _selectedItemColor = UIColor.blackColor()

            // Assign the dynamic label color on iOS 13 and up
            #ifdef __IPHONE_13_0
            if #available(iOS 13.0, *) {
                _selectedItemColor = UIColor.labelColor()
            }
            #endif
        }

        // Set each item to the color
        for item:TOSegmentedControlSegment! in self.segments {  
            item.refreshItemView()
         }
    }

    // -----------------------------------------------
    // Text Font

    func setTextFont(textFont:UIFont!) {
        _textFont = textFont
        if _textFont == nil {
            _textFont = UIFont.systemFontOfSize(13.0, weight:UIFontWeightMedium)
        }

        // Set each item to adopt the new font
        for item:TOSegmentedControlSegment! in self.segments {  
            item.refreshItemView()
         }
    }

    // -----------------------------------------------
    // Selected Text Font

    func setSelectedTextFont(selectedTextFont:UIFont!) {
        _selectedTextFont = selectedTextFont
        if _selectedTextFont == nil {
            _selectedTextFont = UIFont.systemFontOfSize(13.0, weight:UIFontWeightSemibold)
        }

        // Set each item to adopt the new font
        for item:TOSegmentedControlSegment! in self.segments {  
            item.refreshItemView()
         }
    }

    // -----------------------------------------------
    // Thumb Inset

    func setThumbInset(thumbInset:CGFloat) {
        _thumbInset = thumbInset
        self.thumbView.layer.cornerRadius = (self.cornerRadius() - _thumbInset) + 1.0
    }

    // -----------------------------------------------
    // Shadow Properties

    func setThumbShadowOffset(thumbShadowOffset:CGFloat) {self.thumbView.layer.shadowOffset = CGSizeMake(0.0, thumbShadowOffset) }
    func thumbShadowOffset() -> CGFloat { return self.thumbView.layer.shadowOffset.height }

    func setThumbShadowOpacity(thumbShadowOpacity:CGFloat) { self.thumbView.layer.shadowOpacity = thumbShadowOpacity }
    func thumbShadowOpacity() -> CGFloat { return self.thumbView.layer.shadowOpacity }

    func setThumbShadowRadius(thumbShadowRadius:CGFloat) { self.thumbView.layer.shadowRadius = thumbShadowRadius }
    func thumbShadowRadius() -> CGFloat { return self.thumbView.layer.shadowRadius }

    // -----------------------------------------------
    // Number of segments

    func numberOfSegments() -> Int { return self.segments.count }

    // -----------------------------------------------
    // Setting all reversible indexes
    func setReversibleSegmentIndexes(reversibleSegmentIndexes:[AnyObject]!) {
        for var i:Int=0 ; i < self.numberOfSegments() ; i++ {  
            let reversible:Bool = reversibleSegmentIndexes.indexOfObject(i) != NSNotFound
            self.setReversible(reversible, forSegmentAtIndex:i)
         }
    }

    func reversibleSegmentIndexes() -> [AnyObject]! {
        let array:NSMutableArray! = NSMutableArray.array()
        for var i:Int=0 ; i < self.numberOfSegments() ; i++ {  
            if self.isReversibleForSegmentAtIndex(i) {
                array.addObject(i)
            }
         }

        return [AnyObject].arrayWithArray(array)
    }

    // MARK: - Image Creation and Management -

    func arrowImage() -> UIImage! {
        // Retrieve from the image table
        var arrowImage:UIImage! = self.imageTable.objectForKey(kTOSegmentedControlArrowImage)
        if arrowImage != nil { return arrowImage }

        // Generate for the first time
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(8.0, 4.0), false, 0.0)
        {
            let bezierPath:UIBezierPath! = UIBezierPath.bezierPath()
            bezierPath.moveToPoint(CGPointMake(7.25, 0.75))
            bezierPath.addLineToPoint(CGPointMake(4, 3.25))
            bezierPath.addLineToPoint(CGPointMake(0.75, 0.75))
            UIColor.blackColor.setStroke()
            bezierPath.lineWidth = 1.5
            bezierPath.lineCapStyle = kCGLineCapRound
            bezierPath.lineJoinStyle = kCGLineJoinRound
            bezierPath.stroke()
            arrowImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()

        // Force to always be template
        arrowImage = arrowImage.imageWithRenderingMode(UIImageRenderingModeAlwaysTemplate)

        // Save to the map table for next time
        self.imageTable.setObject(arrowImage, forKey:kTOSegmentedControlArrowImage)

        return arrowImage
    }

    func separatorImage() -> UIImage! {
        var separatorImage:UIImage! = self.imageTable.objectForKey(kTOSegmentedControlSeparatorImage)
        if separatorImage != nil { return separatorImage }

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0, 3.0), false, 0.0)
        {
            let separatorPath:UIBezierPath! = UIBezierPath.bezierPathWithRoundedRect(CGRectMake(0, 0, 1, 3), cornerRadius:0.5)
            UIColor.blackColor.setFill()
            separatorPath.fill()
            separatorImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()

        // Format image to be resizable and tint-able.
        separatorImage = separatorImage.resizableImageWithCapInsets(UIEdgeInsetsMake(1.0, 0.0, 1.0, 0.0),
                                                        resizingMode:UIImageResizingModeTile)
        separatorImage = separatorImage.imageWithRenderingMode(UIImageRenderingModeAlwaysTemplate)

        return separatorImage
    }

    func imageTable() -> NSMapTable! {
        // The map table is a global instance that allows all instances of
        // segmented controls to efficiently share the same images.

        // The images themselves are weakly referenced, so they will be cleaned
        // up from memory when all segmented controls using them are deallocated.

        if (_imageTable != nil) { return _imageTable }
        _imageTable = NSMapTable.mapTableWithKeyOptions(NSPointerFunctionsStrongMemory,
                                            valueOptions:NSPointerFunctionsWeakMemory)
        return _imageTable
    }
}
