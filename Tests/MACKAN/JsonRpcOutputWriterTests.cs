#if NET10_0_OR_GREATER

using System;
using System.IO;

using CKAN.MACKAN.Service;

using NUnit.Framework;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class JsonRpcOutputWriterTests
    {
        [Test]
        public void NotificationsRaisedWhileResponsePendingAreWrittenAfterResponse()
        {
            using var writer = new StringWriter();
            var output = new JsonRpcOutputWriter(writer);

            output.BeginResponse();
            output.WriteNotification("{\"jsonrpc\":\"2.0\",\"method\":\"operations.event\"}");
            output.WriteResponse("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"status\":\"running\"}}");

            var lines = writer.ToString()
                .Split(new[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries);
            Assert.That(lines, Has.Length.EqualTo(2));
            Assert.That(lines[0], Does.Contain("\"id\":1"));
            Assert.That(lines[1], Does.Contain("\"operations.event\""));
        }

        [Test]
        public void NotificationsRaisedWithoutPendingResponseAreWrittenImmediately()
        {
            using var writer = new StringWriter();
            var output = new JsonRpcOutputWriter(writer);

            output.WriteNotification("{\"jsonrpc\":\"2.0\",\"method\":\"operations.event\"}");

            Assert.That(writer.ToString(), Does.Contain("\"operations.event\""));
        }
    }
}

#endif
