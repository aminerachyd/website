Written on 2023-07-19

----

---
tags:
  - books
  - software-engineering
  - best-practices
  - code-quality
---

# Clean Code

Robert C. Martin (Uncle Bob) discusses in this book the cleanliness of code, and how it's important to have some guidelines that every professional (ie [clean coder](src/book_reads/the_clean_coder)) should follow in order to produce code that is clean, easy to maintain and easy to read.

Readability is a very important aspect in fact, Uncle Bob mentions nearly in every chapter something about how to name *correctly* basically anything. Functions, variables, classes... all of them should have names that refer to what they *exactly* need to do.

The book walks you through some general guidelines about writing code in certain domains (functions, classes, error handling, testing...), then conducts three case studies (chapters 14,15 and 16) where we try to apply what we have seen to some codebases with real-world use case scenarios.
The last chapter is a compiled list of heuristics to keep in mind when writing code, consider it a small cheatsheet.

Here I'm gathering some ideas I found interesting throughout my read of the book:

### 1. Naming

Let's start with this one. As I said above, everything that *can* be named should be named properly. Naming should be an important concern when writing code; it's good names that communicate the goal of a class or a function without having to read through their code. Yes, reading the code of a function should be the very last resort to knowing what it actually does; the book quotes Ward Cunningham saying the following:

>*You know you are working on clean code when each routine you read turns out to be pretty much what you **expected***

You would *expect* a function that's called **Add** to add numbers, right ?

Names should also *scale* with the length and complexity of the block of code they are referring to it. The longer your function (or class is), the longer its name should be to describe **accurately** what it does (including side effects if they exist). Don't cheap out on names, being too expressive is never a bad practice.

### 2. Small "Everything"

"Small" isn't a precise measurement as far as the book describes it. Uncle Bob tries to give some metrics (about 50-ish lines of code in a function, about 3 methods for classes), but the main metric (if we can call it that way) is that functions, classes, and more generally blocks of code, should do ONE and only ONE job.
This is a very well known principle called SRP (Single Responsibility Principle) and it has actually **two** interpretations: The **first** one being the obvious one, while the **second** one states that a function (or class) should have only **one reason to change**. If a functions has many reasons to change, these reasons implicitly say that the function is handling more than one task, thus violating SRP.

Smallness also occurs when talking about function arguments. Ideally, a function should contain no arguments, and at most 3. If a function accepts many arguments, that may be a sign that these arguments need to be regrouped in their data structure or class.

A couple honourable mentions of some other principles:

- DRY: Don't repeat yourself, code that is being replicated across multiple functions/classes should be extracted into it's own single function
- OCP: Open-Closed principle, classes should be open for extension, but closed for modification. This comes into play when using heritage and interfaces, new functionalities shouldn't change existing classes, but rather rely on interfaces and abstract methods to implement their needs.
- DIP: Dependency Inversion Principle, this states that classes should depend on interfaces, not on other classes. Interfaces define the boundaries of each class, and each class manages internally how it is compliant to its interface. It's internal mechanisms are implementation details that are subject to change and that no other external class should know about.

### 3. Comments

We very commonly think that putting comments in addition to our code is a way to explain it better to the reader. However, Uncle Bob doesn't agree, he actually thinks that comments obfuscate what the code is doing, and they even might turn out to be misleading at some point.

Uncle Bob describes comments as **inability** to have a function being self-describing. It's when we are **unable** to explain the function through it's code that we then should think about writing comments on top of it. Comments should be concise, small as stated before, and must be carefully monitored as they can quickly become obsolete; code changes, comments might not, and in that case they will be more of a burden than a help to their reader.

### 4. Concurrency is Hard

So hard that the book has actually two chapters talking about it.

Some trivial problems in the single-threaded world can become awfully complex when we introduce concurrency and multi-threading. Problems with parallel computing usually occur when trying to share resources; a shared resource can range from a single variable being updated by multiple threads to some more abstract concept like a database connection.

Multi-threaded code should be very concise, and isolated from non-threaded code. That way we can minimise the area of error and possible (and random?) execution paths that concurrent code can have. The way concurrent code is handled is unfortunately (or fortunately ?) out of the hands of the developer, and is being managed instead by the programming language's runtime scheduler, and ultimately by the operating system. At worst, we can hope that our code will be correct enough to have only a few wrong execution paths every million runs. At best, we could use locking mechanisms. One should be careful with these though, as the possibility to introduce deadlocks arises.

### Error handling

A couple thoughts on this one. It seems intuitive nowadays, but code should express its errors through exceptions, not returns codes that are somewhat conventional.
Error handling should also be separated from the actual code. If there are many exceptions that can be triggered, the logic of handling these errors should be encapsulated and abstracted away.

And don't use **null**. They don't call it the [Billion Dollar Mistake](https://www.infoq.com/presentations/Null-References-The-Billion-Dollar-Mistake-Tony-Hoare/) for no reason. There is probably nothing more frustrating than getting a NullPointerException; did the data get cleaned up the garbage collector ? Is it a sign that the function has an error ? Is it the developer that put it as a placeholder for a later time ? Null should be avoided at all costs, whether it's in error handling or in function arguments.

### Testing code

Tests should be small, fast, easily reproducible and integrated with the build process (CI). The author usually refers to TDD as the go-to strategy for testing code while writing it. The benefit of such a method is that it's a trial and error method: You will eventually end up with code the that does what you want of it, and by the time you get there you will have a nice test suite.

One other benefit of having tests integrated with the build process of an application is that we will know if new code broke the existing one, and we will be actually very efficient at locating where it exactly broke if we have a good test suite (ideally being at 100% code coverage, but it's asymptotic).
Having tests also gives more confidence when trying to make a change. Would you commit to a change without knowing if it breaks the code ? Without tests, I would certainly not.
