# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nexlog is a high-performance logging library for Zig applications. It provides a powerful, type-safe API with support for structured logging, context tracking, multiple output handlers, and async mode for demanding applications.

## Build and Development Commands

### Core Commands
- `zig build test` - Run all tests (unit tests + integration tests)
- `zig build bench` - Run performance benchmarks
- `zig build all-examples` - Run all example programs
- `zig build example_<name>` - Run a specific example (e.g., `example_1`, `bench`)

### Individual Test Execution
Tests are located in `tests/` directory. To run a specific test file:
```bash
zig test tests/<test_file>.zig --mod nexlog:src/nexlog.zig
```

### Building the Library
The library builds automatically as a static library via `zig build`.

## Architecture

### Module Structure

**Core Logging System** (`src/core/`):
- `logger.zig` - Main `Logger` struct with thread-safe logging operations
- `types.zig` - Core types: `LogLevel`, `LogMetadata`, `LogContext`, pattern types
- `config.zig` - `LogConfig` for logger configuration
- `init.zig` - Global state management and `LogBuilder` pattern
- `context.zig` - `ContextManager` for request/correlation tracking
- `errors.zig` - Library-specific error types

**Output Handlers** (`src/output/`):
- `handlers.zig` - `LogHandler` interface that all handlers must implement
- `console.zig` - Console output with color support
- `file.zig` - File output with rotation support
- `network.zig` - Network output for remote logging
- `json.zig` - JSON structured output handler

**Utilities** (`src/utils/`):
- `format.zig` - `Formatter` for message formatting and templates
- `buffer.zig` - `CircularBuffer` with health monitoring
- `pool.zig` - Object pooling for performance
- `json.zig` - Minimal JSON generation

**Async Logging** (`src/async/`):
- `core.zig` - `AsyncLogQueue` and `AsyncLogProcessor` for non-blocking logging
- `logger.zig` - `AsyncLogger` wrapper around queue-based architecture
- `console.zig` - Async console handler
- `file.zig` - Async file handler with statistics

### Key Design Patterns

**Global Singleton Pattern**: 
The library uses a `GlobalState` struct in `src/core/init.zig` to manage a default logger instance. This allows global initialization via `nexlog.init()` and access via `nexlog.getDefaultLogger()`.

**Builder Pattern**:
`LogBuilder` provides a fluent API for logger configuration:
```zig
var builder = nexlog.LogBuilder.init();
try builder
    .setMinLevel(.debug)
    .enableFileLogging(true, "logs/app.log")
    .enableAsyncMode(true)
    .build(allocator);
```

**Handler Interface Pattern**:
All output handlers implement the `LogHandler` interface defined in `src/output/handlers.zig`. This uses Zig's function pointer-based polymorphism to create a common interface that different handler types can implement.

**Context Tracking**:
`ContextManager` (in `src/core/context.zig`) manages thread-local storage for request context, allowing automatic correlation of logs across function calls without manual metadata passing.

### Important Implementation Details

**Source Location Tracking**: Users must explicitly pass `@src()` to capture source location. The library provides helper functions like `nexlog.here(@src())` and `nexlog.hereWithContext(@src())` for this purpose.

**Thread Safety**: The main `Logger` uses a mutex to protect concurrent access. The async logging system uses lock-free queues for better performance under high concurrency.

**Formatters**: Separate formatters are used for console (colors enabled) and file (colors disabled) output. This is handled automatically in `Logger.init()`.

**Error Handling**: Logging operations that shouldn't fail use infallible wrapper methods (e.g., `info()`, `debug()`, `warn()`, `err()`) that silently handle errors by printing to stderr.

## Zig Version Compatibility

The project targets Zig 0.14+ and 0.15.0-dev.877+. Recent changes adapted to Zig v0.15.1's removal of gzip compression from the standard library.

## Testing Strategy

- Unit tests are embedded in source files using Zig's `test` blocks
- Integration tests are in `tests/` directory
- Examples in `examples/` serve as both documentation and integration tests
- Performance benchmarks are in `examples/benchmark.zig`

## Working with Async Logging

The async logging system (imported via `nexlog.async_logging`) provides non-blocking operations for high-throughput scenarios. It uses a queue-based architecture with a dedicated processor thread. Key types:
- `AsyncLogger` - Main async logger interface
- `AsyncLogQueue` - Lock-free circular buffer for log entries
- `AsyncLogProcessor` - Background thread that processes queued logs
- `AsyncConsoleHandler`/`AsyncFileHandler` - Async-specific handlers

## Context Tracking for Distributed Systems

The library supports distributed tracing through `LogContext` which includes:
- `request_id` - Request identifier
- `correlation_id` - Correlation across services
- `trace_id`/`span_id` - OpenTelemetry-style distributed tracing
- `user_id`/`session_id` - User/session tracking
- `operation`/`function` - Operation context

Use `nexlog.setRequestContext()` at request entry points and `nexlog.hereWithContext(@src())` for automatic context inclusion in logs.
