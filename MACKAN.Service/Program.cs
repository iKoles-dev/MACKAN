using System;
using System.Diagnostics.CodeAnalysis;

namespace CKAN.MACKAN.Service
{
    internal static class Program
    {
        [ExcludeFromCodeCoverage]
        public static int Main(string[] args)
        {
            var dispatcher = new MackanServiceDispatcher();
            if (args.Length == 1 && args[0] == "--health")
            {
                Console.WriteLine(dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"app.health\"}"));
                return 0;
            }

            if (args.Length > 1 || (args.Length == 1 && args[0] != "--stdio"))
            {
                Console.Error.WriteLine("Usage: MACKAN.Service [--stdio|--health]");
                return 2;
            }

            return RunStdio(dispatcher);
        }

        private static int RunStdio(MackanServiceDispatcher dispatcher)
        {
            string? line;
            while ((line = Console.In.ReadLine()) != null)
            {
                if (line.Length == 0)
                {
                    continue;
                }
                Console.WriteLine(dispatcher.Handle(line));
                Console.Out.Flush();
            }
            return 0;
        }
    }
}
