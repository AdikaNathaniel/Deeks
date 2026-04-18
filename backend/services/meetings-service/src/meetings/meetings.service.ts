import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Meeting, MeetingDocument } from './meeting.schema';
import { CreateMeetingDto } from './dto/create-meeting.dto';
import { UpdateMeetingDto } from './dto/update-meeting.dto';

@Injectable()
export class MeetingsService {
  constructor(
    @InjectModel(Meeting.name)
    private readonly model: Model<MeetingDocument>,
  ) {}

  create(userId: string, dto: CreateMeetingDto) {
    return this.model.create({ ...dto, userId, scheduledAt: new Date(dto.scheduledAt) });
  }

  findAll(userId: string) {
    return this.model.find({ userId }).sort({ scheduledAt: 1 }).exec();
  }

  async findOne(userId: string, id: string) {
    const meeting = await this.model.findOne({ _id: id, userId }).exec();
    if (!meeting) throw new NotFoundException('Meeting not found');
    return meeting;
  }

  async update(userId: string, id: string, dto: UpdateMeetingDto) {
    const updated = await this.model
      .findOneAndUpdate({ _id: id, userId }, dto, { new: true })
      .exec();
    if (!updated) throw new NotFoundException('Meeting not found');
    return updated;
  }

  async remove(userId: string, id: string) {
    const result = await this.model.deleteOne({ _id: id, userId }).exec();
    if (result.deletedCount === 0) throw new NotFoundException('Meeting not found');
    return { deleted: true };
  }
}
