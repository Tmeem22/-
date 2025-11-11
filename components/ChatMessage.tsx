
import React from 'react';
import { ChatMessage, MessageRole } from '../types';

interface ChatMessageProps {
    message: ChatMessage;
}

const ChatMessage: React.FC<ChatMessageProps> = ({ message }) => {
    const isUser = message.role === MessageRole.USER;

    const wrapperClasses = isUser ? 'flex justify-end' : 'flex justify-start';
    const messageClasses = isUser
        ? 'bg-cyan-600 text-white rounded-t-lg rounded-es-lg'
        : 'bg-gray-700 text-gray-200 rounded-t-lg rounded-ee-lg';

    return (
        <div className={wrapperClasses}>
            <div className={`p-3 max-w-lg lg:max-w-xl shadow-md ${messageClasses}`}>
                <p className="whitespace-pre-wrap">{message.content}</p>
            </div>
        </div>
    );
};

export default ChatMessage;
