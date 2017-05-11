import BrightFutures
import Result

public protocol BackoffStrategy {
    func timeToWait(iteration: Int) -> TimeInterval
}

public enum BackoffStrategies: BackoffStrategy {
    case Linear(initialDelay: TimeInterval, delta: TimeInterval)
    case Exponential(initialDelay: TimeInterval, exponentBase: Int)
    public func timeToWait(iteration: Int) -> TimeInterval {
        if iteration == 0 { return 0 }
        switch self {
        case .Linear(let initialDelay, let delta): return initialDelay + (delta * Double(iteration - 1))
        case .Exponential(let initialDelay, let exponentBase): return initialDelay * pow(Double(exponentBase), Double(iteration - 1))
        }
    }
}

public class Retry<T, E: Error> {
    
    var future: Future<T, E> { return self.promise.future }
    public func start() -> Retry {
        if self.started { return self }
        self.started = true
        self.run(remainingAttempts: self.maxAttempts, iteration: 0, after: 0)
        return self
    }
    
    private let maxAttempts: Int?
    private let promise: Promise<T, E>
    private let backoffStrategy: BackoffStrategy
    private let operation: (Void) -> Future<T, E>
    private let queue: DispatchQueue
    private var started = false
    private var lastError: E!
    
    public init(maxAttempts: Int? = nil,
                backoffStrategy: BackoffStrategy = BackoffStrategies.Exponential(initialDelay: 5, exponentBase: 2),
                queue: DispatchQueue = DispatchQueue.global(),
                operation: @escaping (Void) -> Future<T, E>) {
        self.maxAttempts = maxAttempts
        self.backoffStrategy = backoffStrategy
        self.promise = Promise<T, E>()
        self.operation = operation
        self.queue = queue
    }
    
    private func run(remainingAttempts: Int?, iteration: Int, after: TimeInterval) {
        if remainingAttempts == 0 {
            promise.failure(lastError)
            return
        }
        
        let time: DispatchTime = DispatchTime.now() + after
        self.queue.asyncAfter(deadline: time) {
            self.operation()
                .onSuccess(callback: self.promise.success)
                .onFailure(callback: { error in
                self.lastError = error
                let timeToWait = self.backoffStrategy.timeToWait(iteration: iteration + 1)
                self.run(remainingAttempts: remainingAttempts.map({$0 - 1}), iteration: iteration + 1, after: timeToWait)
            })
        }
    }
}

