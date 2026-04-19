// MainThreadBox.swift

@MainActor
public final class MainThreadBox<T>: Sendable {
    public var value: T

    public init(_ value: T) {
        self.value = value
    }

    public init<K>() where T == K? {
        self.value = nil
    }
}

