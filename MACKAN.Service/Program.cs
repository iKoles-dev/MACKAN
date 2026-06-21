using System;
using System.Diagnostics.CodeAnalysis;

namespace CKAN.MACKAN.Service
{
    internal static class Program
    {
        [ExcludeFromCodeCoverage]
        public static int Main(string[] args)
        {
            var output = new JsonRpcOutputWriter(Console.Out);
            var dispatcher = new MackanServiceDispatcher(notificationCallback: output.WriteNotification);

            if (args.Length == 1 && args[0] == "--health")
            {
                output.WriteResponse(dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"app.health\"}"));
                return 0;
            }

            if (args.Length > 1 || (args.Length == 1 && args[0] != "--stdio"))
            {
                Console.Error.WriteLine("Usage: MACKAN.Service [--stdio|--health]");
                return 2;
            }

            return RunStdio(dispatcher, output);
        }

        private static int RunStdio(MackanServiceDispatcher dispatcher, JsonRpcOutputWriter output)
        {
            string? line;
            while ((line = Console.In.ReadLine()) != null)
            {
                if (line.Length == 0)
                {
                    continue;
                }
                output.BeginResponse();
                try
                {
                    var response = dispatcher.Handle(line);
                    output.WriteResponse(response);
                }
                catch
                {
                    output.AbortResponse();
                    throw;
                }
            }
            return 0;
        }
    }
}
