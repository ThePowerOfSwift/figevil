/** To keep track of the index of the current filter. If it reaches the end of filter array by incrementing, it goes back to 0. If it reaches 0 by decrementing, it moves to the end. */
class Index {
    
    /** Holds the end index starting 0. */
    private var count: Int = 0
    /** Holds the current index. */
    var current: Int = 0
    
    /** init with 0 element. */
    init() {
        self.count = 0
        current = 0
    }
    
    /** init with number of element and set current index to 0. */
    init(numOfElement: Int) {
        self.count = numOfElement - 1
        current = 0
    }
    
    /** Increments current by 1 and return it. If it reaches the end, it goes back to index 0. */
    internal func increment() -> Int {
        if current == count {
            current = 0
        } else {
            current = current + 1
        }
        return current
    }
    
    /** Decrements current by 1 and return it. If it reaches 0, it moves to the end. */
    internal func decrement() -> Int {
        if current == 0 {
            current = count
        } else {
            current = current - 1
        }
        return current
    }
}
